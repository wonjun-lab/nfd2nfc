# nfd2nfc

macOS 한글 파일명 **자소분리(NFD → NFC)** 정리 도구. Finder 우클릭(빠른 동작)과 CLI를 함께 제공합니다.
추가 설치 없이 macOS 기본 `perl`만으로 동작합니다.

> **EN:** Fixes macOS NFD filenames (e.g. Korean `안녕` appearing as `ㅇㅏㄴㄴㅕㅇ` on Windows/web uploads)
> by normalizing file & folder names to NFC. Ships as a Finder Quick Action and a CLI. Zero dependencies — uses the `perl` already on macOS.

## 왜 필요한가

macOS는 파일명을 **NFD(분해형)**로 저장합니다. 그래서 한글 파일명이 윈도우나 일부 웹 업로드(특히 Chrome)에서
`ㅇㅏㄴㄴㅕㅇ`처럼 자소분리되어 보입니다. 이 도구는 이름을 **NFC(조합형)**로 바꿔 그 문제를 없앱니다.

화면에 보이는 글자는 그대로이고 내부 유니코드 인코딩만 정규화하므로 안전합니다. 이미 정상(NFC)인 파일은
건드리지 않고, 같은 이름의 다른 파일이 충돌하면 건너뛰며, 여러 번 실행해도 안전(idempotent)합니다.

## 설치 — 한 줄 설치 (추천)

저장소를 내려받은 폴더에서 터미널로 한 줄만 실행하면 **Finder 우클릭 메뉴 + 터미널 명령**이 한 번에 설치됩니다.

```sh
./install.sh
```

- Finder 우클릭 메뉴 `NFC로 이름 정리` 가 즉시 추가됩니다(더블클릭·보안 승인 불필요).
- 터미널 명령 `nfd2nfc` 가 PATH에 설치됩니다.

제거는 `./uninstall.sh`.

> 메뉴가 바로 안 보이면 잠깐 기다렸다 다시 우클릭하거나, 로그아웃 후 다시 로그인하세요.
> **시스템 설정 → 키보드 → 키보드 단축키 → 서비스**에서 켜고 끌 수 있습니다.

## 설치 — Finder 우클릭 메뉴만 (터미널 없이)

터미널을 쓰지 않으려면 미리 빌드된 Quick Action을 더블클릭으로 설치할 수 있습니다.

1. `NFC로 이름 정리.workflow.zip`의 압축을 풉니다.
2. 나온 **`NFC로 이름 정리.workflow`** 를 더블클릭 → *"빠른 동작을 설치하시겠습니까?"* 에서 **설치**.
3. Finder에서 파일·폴더 우클릭 → **빠른 동작(Quick Actions) → `NFC로 이름 정리`**.

폴더를 선택하면 하위 전체를 한 번에 정리하고, 끝나면 알림이 뜹니다.

> 더블클릭이 보안으로 막히면 **우클릭 → 열기** 로 한 번 실행하세요.

## CLI 사용법

`./install.sh` 로 설치했다면 어디서나 `nfd2nfc` 로 호출할 수 있습니다. 설치 없이 바로 쓰려면:

```sh
chmod +x nfd2nfc                          # 최초 1회 실행 권한 부여
./nfd2nfc ~/Downloads/내폴더               # 폴더 안 전체를 NFC로 정리(하위 포함)
./nfd2nfc --dry-run ~/Downloads/*.hwp      # 실제로 바꾸기 전 미리보기
./nfd2nfc --notify ~/Desktop/사진들         # 끝나면 macOS 알림
./nfd2nfc --no-recurse ./첨부               # 하위 폴더는 건드리지 않고 지정 항목만
./nfd2nfc -v 보고서.pdf 자료.xlsx            # 여러 파일, 변경 내역 출력
```

| 옵션 | 설명 |
|------|------|
| `-n`, `--dry-run` | 실제로 바꾸지 않고 미리보기 |
| `--no-recurse` | 지정 항목만 처리(하위 폴더 제외) |
| `--notify` | 완료 후 macOS 알림 |
| `-v`, `--verbose` | 변경 내역 출력 |
| `-h`, `--help` | 도움말 |

## 동작 방식

- 대상 경로를 모은 뒤 **깊은 경로(자식)부터** 처리해, 폴더 이름을 바꿔도 하위 경로가 깨지지 않습니다.
- 파일명을 NFC로 정규화한 값이 기존과 다를 때만 `rename` 합니다(이미 NFC면 무시).
- macOS 파일시스템(APFS·HFS+)은 **정규화 비구분**이라, NFD 파일도 NFC 이름으로 조회하면 "존재"로 잡힙니다.
  그래서 단순 존재 검사 대신 **inode를 비교**해, *진짜 다른 파일*이 그 이름을 차지한 경우에만 건너뜁니다.

## 직접 Quick Action 만들기 (수동, 폴백)

`install.sh`나 zip을 못 쓰는 경우, Automator로 직접 만들 수 있습니다.

`Automator` → 새 문서 → **빠른 동작** → *받는 입력:* **파일 또는 폴더**, *위치:* **Finder.app** →
**셸 스크립트 실행** 추가 → *셸:* `/bin/zsh`, *입력 전달:* **인수로** → 아래를 붙여넣고
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
  # APFS는 정규화 비구분 → NFC 이름도 자기 자신으로 잡힌다.
  # inode를 비교해 "진짜 다른 파일"이 있을 때만 건너뛴다.
  my @cur = lstat($p); my @tgt = lstat($new);
  if (@tgt && (!@cur || $tgt[0] != $cur[0] || $tgt[1] != $cur[1])) { $s++; next; }
  $c++ if rename($p, $new);
}
my $msg = "이름 정리 완료: ${c}개 변경" . ($s ? ", ${s}개 건너뜀" : "");
system("/usr/bin/osascript", "-e",
       "display notification \"$msg\" with title \"NFC 이름 정리\"");' "$@"
```

> 저장소의 `NFC로 이름 정리.workflow.zip`은 `build-workflow.sh`가 `nfd2nfc` 본문을 그대로 임베드해
> 자동 생성합니다. 스크립트를 고치면 `./build-workflow.sh`로 zip을 다시 만드세요.

## 근본 해결(서버 쪽)

받는 서버를 직접 운영한다면, 업로드 시 서버에서 NFC 정규화하는 것이 가장 완전한 해결입니다.

```python
import unicodedata
filename = unicodedata.normalize("NFC", filename)
```

이 저장소의 도구는 그게 불가능한 "올리는 쪽 사용자"를 위한 처방입니다.

## License

MIT
