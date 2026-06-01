<div align="center">

# 📁 nfd2nfc

**macOS 한글 파일명 자소분리, 우클릭 한 번으로 해결**

`안녕.txt` 가 `ㅇㅏㄴㄴㅕㅇ.txt` 로 깨지는 그 문제 — 추가 설치 없이 macOS 기본 도구만으로 정리합니다.

![CI](https://github.com/wonjun-lab/nfd2nfc/actions/workflows/ci.yml/badge.svg)
![Version](https://img.shields.io/github/v/tag/wonjun-lab/nfd2nfc?label=version)
![License](https://img.shields.io/badge/license-MIT-blue)
![Platform](https://img.shields.io/badge/macOS-zero%20deps-black?logo=apple)

</div>

---

## 🤔 무슨 문제냐면

macOS는 한글을 **자모 단위로 분해(NFD)**해서 저장합니다. 화면에선 멀쩡해 보이지만, 윈도우나 웹 업로드(특히 Chrome)로 넘어가면 자소가 흩어져 보입니다.

| 내 Mac에서는 | 윈도우 · 웹 업로드에서는 |
| :---: | :---: |
| `보고서.hwp` ✅ | `ㅂㅗㄱㅗㅅㅓ.hwp` 😱 |
| `안녕 사진들/` ✅ | `ㅇㅏㄴㄴㅕㅇ ㅅㅏㅈㅣㄴㄷㅡㄹ/` 😱 |

**nfd2nfc**는 파일·폴더 이름을 **조합형(NFC)**으로 바꿔 이 문제를 없앱니다.
보이는 글자는 그대로, 내부 인코딩만 정규화하므로 **안전**합니다.

---

## ⚡ 설치

쉬운 순서대로. 하나만 골라서 쓰면 됩니다.

### 🖱️ 1. Finder 우클릭 메뉴 — 터미널 불필요 (가장 쉬움)

1. [**Releases**](https://github.com/wonjun-lab/nfd2nfc/releases)에서 `NFC로 이름 정리.workflow.zip`을 받아 압축을 풉니다.
2. 나온 **`NFC로 이름 정리.workflow`**를 더블클릭 → *"빠른 동작을 설치하시겠습니까?"* 에서 **설치**.
3. 끝! 이제 파일·폴더를 우클릭 → **빠른 동작 → `NFC로 이름 정리`**.

> 더블클릭이 보안으로 막히면 **우클릭 → 열기**로 한 번만 실행하세요.

### 🚀 2. 한 줄 설치 — 우클릭 메뉴 + 터미널 명령 한 번에

```sh
./install.sh
```

Finder 우클릭 메뉴와 `nfd2nfc` 명령이 함께 설치됩니다. 제거는 `./uninstall.sh`.

### 🍺 3. Homebrew — CLI만

```sh
brew install wonjun-lab/tap/nfd2nfc
```

---

## 🖱️ 사용법

### Finder에서

파일이나 폴더(여러 개도 OK)를 선택 → **우클릭 → 빠른 동작 → `NFC로 이름 정리`**.
폴더를 고르면 **안쪽 전체**를 한 번에 정리하고, 끝나면 알림이 뜹니다.

### 터미널에서

```sh
nfd2nfc ~/Downloads/내폴더            # 폴더 안 전체 정리 (하위 포함)
nfd2nfc --dry-run ~/Desktop/*.hwp     # 바꾸기 전에 미리보기
nfd2nfc --notify ~/사진들              # 끝나면 알림
nfd2nfc -v 보고서.pdf 자료.xlsx        # 여러 파일 + 변경 내역 출력
```

| 옵션 | 설명 |
| --- | --- |
| `-n`, `--dry-run` | 실제로 바꾸지 않고 미리보기 |
| `--no-recurse` | 지정한 항목만 (하위 폴더 제외) |
| `--notify` | 완료 후 macOS 알림 |
| `-v`, `--verbose` | 변경 내역 한 줄씩 출력 |
| `-V`, `--version` | 버전 출력 |
| `-h`, `--help` | 도움말 |

---

## 🔒 안전한가요?

네. 보수적으로 동작합니다.

- ✅ **보이는 글자는 그대로** — 내부 유니코드 정규형만 바꿉니다.
- ✅ **이미 정상(NFC)인 파일은 건드리지 않음.**
- ✅ **여러 번 실행해도 안전** (idempotent) — 바꿀 게 없으면 아무 일도 안 합니다.
- ✅ **깊은 폴더부터 처리**해, 폴더 이름을 바꿔도 하위 경로가 깨지지 않습니다.
- ✅ **심볼릭 링크를 따라 들어가지 않습니다.**

> 💡 macOS 파일시스템(APFS·HFS+)은 정규화를 구분하지 않아, NFD 파일도 NFC 이름으로 조회하면 "존재"로 잡힙니다. nfd2nfc는 단순 존재 검사 대신 **inode를 비교**해 *진짜 다른 파일*이 그 이름을 차지한 경우에만 건너뜁니다.

---

## 🧩 근본 해결 (서버를 직접 운영한다면)

받는 서버를 직접 운영한다면, 업로드 시 서버에서 정규화하는 것이 가장 완전합니다.

```python
import unicodedata
filename = unicodedata.normalize("NFC", filename)
```

nfd2nfc는 그게 불가능한 **"올리는 쪽 사용자"**를 위한 처방입니다.

---

<details>
<summary>🛠️ Quick Action을 직접 만들기 (수동 폴백)</summary>

<br>

`install.sh`나 zip을 쓸 수 없을 때, Automator로 직접 만들 수 있습니다.

`Automator` → 새 문서 → **빠른 동작** → *받는 입력:* **파일 또는 폴더**, *위치:* **Finder.app** →
**셸 스크립트 실행** 추가 → *셸:* `/bin/zsh`, *입력 전달:* **인수로** → 아래를 붙여넣고
이름을 `NFC로 이름 정리`로 저장합니다.

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

> 저장소의 `NFC로 이름 정리.workflow.zip`은 `build-workflow.sh`가 `nfd2nfc` 본문을 그대로 임베드해 자동 생성합니다. 스크립트를 고치면 `./build-workflow.sh`로 다시 만드세요.

</details>

---

## 🤝 기여 · 개발

테스트·릴리스 절차는 [CONTRIBUTING.md](CONTRIBUTING.md)를, 변경 이력은 [CHANGELOG.md](CHANGELOG.md)를 참고하세요.

```sh
./test.sh        # 통합 테스트 (macOS 전용)
```

---

## English

**nfd2nfc** fixes macOS NFD filenames — Korean names like `안녕.txt` that show up as
`ㅇㅏㄴㄴㅕㅇ.txt` on Windows or web uploads — by normalizing files & folders to NFC.
Zero dependencies; it uses the `perl` already on macOS. The visible characters stay the
same; only the underlying Unicode form is normalized.

| Install | Command |
| --- | --- |
| 🖱️ Finder only (no terminal) | Download `.workflow.zip` from [Releases](https://github.com/wonjun-lab/nfd2nfc/releases) and double-click |
| 🚀 CLI + Finder Quick Action | `./install.sh` |
| 🍺 Homebrew (CLI) | `brew install wonjun-lab/tap/nfd2nfc` |

```
nfd2nfc [--dry-run] [--no-recurse] [--notify] [-v] [-V] <paths...>
```

It's safe: already-NFC files are left alone, name clashes with *different* files are
skipped, and re-running is idempotent.

---

## License

[MIT](LICENSE)
