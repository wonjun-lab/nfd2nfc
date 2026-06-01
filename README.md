# nfd2nfc

macOS 한글 파일명 **자소분리(NFD → NFC)** 정리 도구. Finder 우클릭(빠른 동작)과 CLI를 함께 제공합니다.
추가 설치 없이 macOS 기본 `perl`만으로 동작합니다.

> **EN:** Fixes macOS NFD filenames (e.g. Korean `안녕` appearing as `ㅇㅏㄴㄴㅕㅇ` on Windows/web uploads)
> by normalizing file & folder names to NFC. Ships as a Finder Quick Action and a CLI. Zero dependencies — uses the `perl` already on macOS.

## 왜 필요한가

macOS는 파일명을 **NFD(분해형)**로 저장합니다. 그래서 한글 파일명이 윈도우나 일부 웹 업로드(특히 Chrome)에서
`ㅇㅏㄴㄴㅕㅇ`처럼 자소분리되어 보입니다. 이 도구는 이름을 **NFC(조합형)**로 바꿔 그 문제를 없앱니다.

화면에 보이는 글자는 그대로이고 내부 유니코드 인코딩만 정규화하므로 안전합니다. 이미 정상(NFC)인 파일은
건드리지 않고, 같은 이름이 충돌하면 건너뛰며, 여러 번 실행해도 안전(idempotent)합니다.

## 설치 — Finder 우클릭 메뉴 (추천)

1. `NFC로 이름 정리.workflow.zip`의 압축을 풉니다.
2. 나온 **`NFC로 이름 정리.workflow`** 를 더블클릭 → *"빠른 동작을 설치하시겠습니까?"* 에서 **설치**.
3. Finder에서 파일·폴더 우클릭 → **빠른 동작(Quick Actions) → `NFC로 이름 정리`**.

폴더를 선택하면 하위 전체를 한 번에 정리하고, 끝나면 알림이 뜹니다.
설치 항목은 **시스템 설정 → 키보드 → 키보드 단축키 → 서비스** 에서 켜고 끌 수 있습니다.

> 더블클릭이 보안으로 막히면 **우클릭 → 열기** 로 한 번 실행하세요. Quick Action이 안 보이면 아래 *직접 만들기*를 참고하세요.

## 설치 — Automator로 직접 만들기 (1분, 가장 확실)

`Automator` → 새 문서 → **빠른 동작** → *받는 입력:* **파일 또는 폴더**, *위치:* **Finder.app** →
**셸 스크립트 실행** 추가 → *셸:* `/bin/zsh`, *입력 전달:* **인수로** → 아래 한 줄을 붙여넣고
이름을 `NFC로 이름 정리` 로 저장합니다.

```sh
/usr/bin/perl -e 'use strict; use warnings;
use Unicode::Normalize qw(NFC);
use Encode qw(decode_utf8 encode_utf8);
my @t;
sub col {
  my $p = shift; $p =~ s{/+$}{}; return if $p eq "";
  push @t, $p;
  if (-d $p && !-l $p && opendir(my $d, $p)) {
    my @e = readdir($d); closedir($d);
    for my $x (@e) { next if $x eq "." || $x eq ".."; col("$p/$x"); }
  }
}
col($_) for @ARGV;
my ($c, $s) = (0, 0);
for my $p (sort { ($b =~ tr{/}{}) <=> ($a =~ tr{/}{}) } @t) {
  my $i = rindex($p, "/");
  my $dir  = $i == -1 ? "" : substr($p, 0, $i + 1);
  my $base = $i == -1 ? $p : substr($p, $i + 1);
  my $u = eval { my $cp = $base; decode_utf8($cp, Encode::FB_CROAK) };
  next unless defined $u;
  my $nb = encode_utf8(NFC($u));
  next if $nb eq $base;
  my $new = $dir . $nb;
  if (-e $new || -l $new) { $s++; next; }
  $c++ if rename($p, $new);
}
my $msg = "이름 정리 완료: ${c}개 변경" . ($s ? ", ${s}개 건너뜀" : "");
system("/usr/bin/osascript", "-e",
       "display notification \"$msg\" with title \"NFC 이름 정리\"");' "$@"
```

## CLI 사용법

```sh
chmod +x nfd2nfc                          # 최초 1회 실행 권한 부여
./nfd2nfc ~/Downloads/내폴더               # 폴더 안 전체를 NFC로 정리(하위 포함)
./nfd2nfc --dry-run ~/Downloads/*.hwp      # 실제로 바꾸기 전 미리보기
./nfd2nfc --notify ~/Desktop/사진들         # 끝나면 macOS 알림
./nfd2nfc --no-recurse ./첨부               # 하위 폴더는 건드리지 않고 지정 항목만
./nfd2nfc -v 보고서.pdf 자료.xlsx            # 여러 파일, 변경 내역 출력
sudo cp nfd2nfc /usr/local/bin/            # 어디서나 nfd2nfc 명령으로 호출
```

| 옵션 | 설명 |
|------|------|
| `-n`, `--dry-run` | 실제로 바꾸지 않고 미리보기 |
| `--no-recurse` | 지정 항목만 처리(하위 폴더 제외) |
| `--notify` | 완료 후 macOS 알림 |
| `-v`, `--verbose` | 변경 내역 출력 |
| `-h`, `--help` | 도움말 |

## 근본 해결(서버 쪽)

받는 서버를 직접 운영한다면, 업로드 시 서버에서 NFC 정규화하는 것이 가장 완전한 해결입니다.

```python
import unicodedata
filename = unicodedata.normalize("NFC", filename)
```

이 저장소의 도구는 그게 불가능한 "올리는 쪽 사용자"를 위한 처방입니다.

## 동작 방식

- 대상 경로를 모은 뒤 **깊은 경로(자식)부터** 처리해, 폴더 이름을 바꿔도 하위 경로가 깨지지 않습니다.
- 파일명을 NFC로 정규화한 값이 기존과 다를 때만 `rename` 합니다(이미 NFC면 무시).
- 대상 이름이 이미 존재하면 덮어쓰지 않고 건너뜁니다.

## License

MIT
