# nfd2nfc 공개 릴리스 다듬기 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `nfd2nfc`를 공개 릴리스(v1.0.0) 품질로 다듬는다 — 저장소 정리, 버전 플래그, 통합 테스트, CI/릴리스 자동화, Homebrew formula, 문서/메타.

**Architecture:** `nfd2nfc`(perl) 단일 원본 → `build-workflow.sh`가 Quick Action에 임베드 → `install.sh`가 source → `test.sh`가 전부 검증 → CI가 `test.sh` 실행. 빌드 산출물(zip)은 커밋하지 않고 릴리스 자산으로만 배포.

**Tech Stack:** perl 5(시스템 기본), POSIX sh/bash, GitHub Actions(macos-latest), shellcheck, Homebrew, plutil.

> **설계 변경 반영:** `--on-conflict` 옵션은 제외됨. macOS 정규화 비구분 FS에선 제자리 정규화 시 대상 NFC 이름이 항상 원본과 같은 inode라 "진짜 충돌"이 발생할 수 없어(죽은 코드·테스트 불가) 빼기로 결정.

---

## File Structure

- `nfd2nfc` — CLI 코어. `--version` 추가 (Modify).
- `test.sh` — 통합 테스트 하니스 (Create). 로컬·CI 공용 단일 진실 공급원.
- `nfd2nfc.rb` — Homebrew formula (Create).
- `.github/workflows/ci.yml` — 문법검사+shellcheck+test (Create).
- `.github/workflows/release.yml` — 태그 시 zip 빌드·첨부 (Create).
- `.github/ISSUE_TEMPLATE/bug_report.md`, `feature_request.md` (Create).
- `CHANGELOG.md`, `CONTRIBUTING.md` (Create).
- `README.md` — 배지·설치 3경로·영문·신규 옵션 (Modify).
- `.gitignore` — workflow.zip 무시 추가 (Modify).
- `NFC로 이름 정리.workflow.zip` — git에서 제거 (Delete).

---

## Task 1: 통합 테스트 하니스 `test.sh` (현행 동작 기준선)

현재 `nfd2nfc`가 이미 통과해야 하는 동작을 스크립트화한다. `--version` 테스트는 Task 2에서 같은 파일에 추가한다.

**Files:**
- Create: `test.sh`

- [ ] **Step 1: `test.sh` 작성**

```bash
#!/usr/bin/env bash
# test.sh — nfd2nfc 통합 테스트 (macOS/APFS 전용)
# 정규화 비구분 FS 동작에 의존하므로 반드시 macOS에서 실행.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
NFD2NFC="$HERE/nfd2nfc"
PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf '  \033[31m✗\033[0m %s\n' "$1"; }

# 디렉토리 아래 NFD로 남은 항목 수 출력
count_nfd() {
    /usr/bin/perl -CSDA -MFile::Find -e '
        use Unicode::Normalize qw(NFC); use Encode qw(decode_utf8);
        my $n = 0;
        find(sub {
            return if $_ eq ".";
            my $u = eval { my $c = $_; decode_utf8($c, Encode::FB_CROAK) };
            return unless defined $u;
            $n++ if NFC($u) ne $u;
        }, $ARGV[0]);
        print $n;
    ' "$1"
}

# 표준 NFD 픽스처: <dir>/보고서.hwp, <dir>/하위폴더/사진.jpg
make_fixture() {
    base="$1"
    mkdir -p "$base"
    /usr/bin/perl -e '
        use Unicode::Normalize qw(NFD); use Encode qw(encode_utf8);
        my $b = $ARGV[0];
        open(my $f, ">", "$b/" . encode_utf8(NFD("보고서.hwp"))) or die "$!"; close $f;
        my $d = "$b/" . encode_utf8(NFD("하위폴더")); mkdir $d or die "$!";
        open($f, ">", "$d/" . encode_utf8(NFD("사진.jpg"))) or die "$!"; close $f;
    ' "$base"
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "== nfd2nfc 통합 테스트 =="

# [1] 기본 변환: 중첩 포함 전부 NFC
make_fixture "$TMP/t1"
/usr/bin/perl "$NFD2NFC" "$TMP/t1" >/dev/null 2>&1
[ "$(count_nfd "$TMP/t1")" -eq 0 ] && ok "기본 변환(중첩 포함) 전부 NFC" || ng "기본 변환 실패"

# [2] idempotent: 재실행 0개 변경
out=$(/usr/bin/perl "$NFD2NFC" "$TMP/t1" 2>&1)
echo "$out" | grep -q "0개 변경" && ok "idempotent 재실행 0개 변경" || ng "idempotent 실패: $out"

# [3] dry-run: 변경 없음
make_fixture "$TMP/t3"
/usr/bin/perl "$NFD2NFC" --dry-run "$TMP/t3" >/dev/null 2>&1
[ "$(count_nfd "$TMP/t3")" -eq 3 ] && ok "dry-run은 실제 변경 안 함" || ng "dry-run이 파일을 변경함"

# [4] --no-recurse: 지정 폴더만, 하위는 유지
make_fixture "$TMP/t4"
sub=$(/usr/bin/perl -e 'opendir(my$d,$ARGV[0]);for(readdir$d){next if/^\.\.?$/;next unless -d "$ARGV[0]/$_";print "$ARGV[0]/$_";last}' "$TMP/t4")
/usr/bin/perl "$NFD2NFC" --no-recurse "$sub" >/dev/null 2>&1
[ "$(count_nfd "$TMP/t4")" -ge 1 ] && ok "--no-recurse는 하위 미처리" || ng "--no-recurse가 하위까지 처리함"

# [5] 심볼릭 링크 미추적
mkdir -p "$TMP/t5"
/usr/bin/perl -e '
    use Unicode::Normalize qw(NFD); use Encode qw(encode_utf8);
    my $b = $ARGV[0];
    my $real = "$b/" . encode_utf8(NFD("실제폴더")); mkdir $real;
    symlink($real, "$b/" . encode_utf8(NFD("링크"))) or die "$!";
' "$TMP/t5"
/usr/bin/perl "$NFD2NFC" "$TMP/t5" >/dev/null 2>&1
link_count=$(/usr/bin/perl -e 'my$n=0;opendir(my$d,$ARGV[0]);for(readdir$d){next if/^\.\.?$/;$n++ if -l "$ARGV[0]/$_"}print$n' "$TMP/t5")
{ [ "$link_count" -eq 1 ] && [ "$(count_nfd "$TMP/t5")" -eq 0 ]; } && ok "심볼릭 링크 미추적 + 이름만 정규화" || ng "심볼릭 링크 처리 이상"

# [6] 생성된 Quick Action 명령 실행 (Automator 임시파일 방식)
"$HERE/build-workflow.sh" >/dev/null 2>&1
unzip -oq "$HERE/NFC로 이름 정리.workflow.zip" -d "$TMP/wf"
DOC=$(find "$TMP/wf" -name document.wflow)
/usr/bin/plutil -extract "actions.0.action.ActionParameters.COMMAND_STRING" raw -o "$TMP/qa_cmd.sh" "$DOC"
make_fixture "$TMP/t6"
/usr/bin/perl -e '
    my @a; opendir(my $d, $ARGV[1]); for (readdir $d) { next if /^\.\.?$/; push @a, "$ARGV[1]/$_" } closedir $d;
    system("/bin/zsh", $ARGV[0], @a);
' "$TMP/qa_cmd.sh" "$TMP/t6"
[ "$(count_nfd "$TMP/t6")" -eq 0 ] && ok "Quick Action 명령 실행 변환 성공" || ng "Quick Action 명령 변환 실패"

echo "----"
echo "통과 $PASS / 실패 $FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 실행 권한 부여 후 실행 — 전부 통과 확인**

Run:
```bash
chmod +x test.sh && ./test.sh; echo "exit=$?"
```
Expected: 모든 케이스 `✓`, 마지막 `통과 6 / 실패 0`, `exit=0`.

- [ ] **Step 3: shellcheck 통과 확인**

Run: `shellcheck test.sh` (없으면 `brew install shellcheck`)
Expected: 경고 없음. 남으면 수정(예: `SC2317` 등). 빌드된 zip은 `.gitignore` 대상이니 커밋하지 않는다.

- [ ] **Step 4: Commit**

```bash
git add test.sh
git commit -m "test: 통합 테스트 하니스 추가 (현행 동작 기준선)"
```

---

## Task 2: `--version` / `-V` 플래그 (TDD)

**Files:**
- Modify: `nfd2nfc` (옵션 변수 라인 27, GetOptions 28-34, usage 도움말, 처리 분기)
- Modify: `test.sh`

- [ ] **Step 1: 실패 테스트를 `test.sh`에 추가**

`test.sh`의 `echo "----"` 줄 **앞에** 아래 블록을 삽입:

```bash
# [버전] --version 출력 형식
ver_out=$(/usr/bin/perl "$NFD2NFC" --version 2>&1)
echo "$ver_out" | grep -Eq '^nfd2nfc [0-9]+\.[0-9]+\.[0-9]+$' && ok "--version 출력 형식" || ng "--version 형식 이상: $ver_out"
# -V 단축 일치
v2=$(/usr/bin/perl "$NFD2NFC" -V 2>&1)
[ "$v2" = "$ver_out" ] && ok "-V 단축 일치" || ng "-V 불일치: $v2"
```

- [ ] **Step 2: 실패 확인**

Run: `./test.sh; echo "exit=$?"`
Expected: 새 두 케이스 `✗`, `exit=1` (현재 `--version` 미지원이라 도움말 출력).

- [ ] **Step 3: `nfd2nfc` 구현**

`use Getopt::Long qw(GetOptions);` 다음 줄에 버전 상수 추가:

```perl
our $VERSION = "1.0.0";
```

옵션 변수 라인(현재 `my ($dry, $recurse, $notify, $verbose, $help) = (0, 1, 0, 0, 0);`)을 교체:

```perl
my ($dry, $recurse, $notify, $verbose, $help, $version) = (0, 1, 0, 0, 0, 0);
```

GetOptions 블록과 그 직후를 다음으로 교체:

```perl
GetOptions(
    'dry-run|n'  => \$dry,
    'recurse!'   => \$recurse,
    'notify'     => \$notify,
    'verbose|v'  => \$verbose,
    'version|V'  => \$version,
    'help|h'     => \$help,
) or usage(1);

if ($version) { print "nfd2nfc $VERSION\n"; exit 0; }
usage(0) if $help;
usage(1) unless @ARGV;
```

usage 도움말 텍스트의 `-v, --verbose` 줄 아래에 추가:

```
  -V, --version     버전 출력
```

- [ ] **Step 4: 통과 확인 + perl 문법**

Run: `/usr/bin/perl -c nfd2nfc && ./test.sh; echo "exit=$?"`
Expected: `nfd2nfc syntax OK`, 전부 `✓`, `exit=0`.

- [ ] **Step 5: Commit**

```bash
git add nfd2nfc test.sh
git commit -m "feat: --version/-V 플래그 추가"
```

---

## Task 3: 빌드 산출물 zip을 버전관리에서 제거

**Files:**
- Modify: `.gitignore`
- Delete (from git): `NFC로 이름 정리.workflow.zip`

- [ ] **Step 1: `.gitignore`에 추가**

`.gitignore` 끝에 추가:

```
# 빌드 산출물 (build-workflow.sh가 생성, 릴리스 자산으로 배포)
NFC로 이름 정리.workflow.zip
*.workflow/
```

- [ ] **Step 2: git에서 제거(작업트리 파일은 유지)**

Run: `git rm --cached "NFC로 이름 정리.workflow.zip"`
Expected: `rm 'NFC로 이름 정리.workflow.zip'`

- [ ] **Step 3: 무시 확인**

Run: `git status --porcelain`
Expected: zip은 추적 해제·무시되어 목록에 없고, `.gitignore`만 `M`.

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore: 빌드 산출물 workflow.zip을 버전관리에서 제거"
```

---

## Task 4: Homebrew formula `nfd2nfc.rb`

**Files:**
- Create: `nfd2nfc.rb`

- [ ] **Step 1: formula 작성**

```ruby
class Nfd2nfc < Formula
  desc "Fix macOS NFD Korean filenames by normalizing to NFC"
  homepage "https://github.com/wonjun-lab/nfd2nfc"
  url "https://github.com/wonjun-lab/nfd2nfc/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000" # 릴리스 후 실제 sha256으로 교체 (CONTRIBUTING 참고)
  license "MIT"

  def install
    bin.install "nfd2nfc"
  end

  test do
    assert_match "nfd2nfc", shell_output("#{bin}/nfd2nfc --version")
  end
end
```

- [ ] **Step 2: 루비 문법 확인**

Run: `ruby -c nfd2nfc.rb`
Expected: `Syntax OK`

- [ ] **Step 3: Commit**

```bash
git add nfd2nfc.rb
git commit -m "feat: Homebrew formula 추가 (tap 배포용 원본)"
```

---

## Task 5: CI 워크플로 `.github/workflows/ci.yml`

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: 작성**

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: perl 문법 검사
        run: /usr/bin/perl -c nfd2nfc

      - name: shellcheck 설치
        run: brew install shellcheck

      - name: shellcheck
        run: shellcheck install.sh uninstall.sh build-workflow.sh test.sh

      - name: 통합 테스트
        run: ./test.sh
```

- [ ] **Step 2: YAML 유효성(로컬) 확인**

Run: `/usr/bin/python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" 2>/dev/null && echo OK || echo "python yaml 없음 — 건너뜀(GitHub가 검증)"`
Expected: `OK` 또는 건너뜀.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: macOS에서 perl -c + shellcheck + 통합 테스트"
```

---

## Task 6: 릴리스 워크플로 `.github/workflows/release.yml`

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: 작성**

```yaml
name: Release

on:
  push:
    tags: ["v*"]

permissions:
  contents: write

jobs:
  release:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Quick Action zip 빌드
        run: ./build-workflow.sh

      - name: GitHub Release 생성 + zip 첨부
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release create "${GITHUB_REF_NAME}" \
            "NFC로 이름 정리.workflow.zip" \
            --title "${GITHUB_REF_NAME}" \
            --generate-notes
```

- [ ] **Step 2: YAML 유효성 확인**

Run: `/usr/bin/python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))" 2>/dev/null && echo OK || echo "건너뜀"`
Expected: `OK` 또는 건너뜀.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: 태그 푸시 시 Quick Action zip 빌드·릴리스 첨부"
```

---

## Task 7: 이슈 템플릿

**Files:**
- Create: `.github/ISSUE_TEMPLATE/bug_report.md`
- Create: `.github/ISSUE_TEMPLATE/feature_request.md`

- [ ] **Step 1: `bug_report.md` 작성**

```markdown
---
name: 버그 신고
about: 동작이 기대와 다를 때
labels: bug
---

## 무슨 일이 있었나요
<!-- 무엇을 했고, 무엇을 기대했고, 실제로 무엇이 일어났는지 -->

## 재현 방법
1.
2.

## 환경
- macOS 버전:
- 설치 방법: (Homebrew / install.sh / Quick Action zip)
- `nfd2nfc --version` 출력:

## 추가 정보
<!-- 파일명 예시(가능하면), 오류 메시지 등 -->
```

- [ ] **Step 2: `feature_request.md` 작성**

```markdown
---
name: 기능 제안
about: 새로운 기능이나 개선 아이디어
labels: enhancement
---

## 해결하려는 문제
<!-- 어떤 상황에서 무엇이 불편한가요 -->

## 제안하는 방법
<!-- 어떻게 동작하면 좋을지 -->

## 대안
<!-- 고려한 다른 방법이 있다면 -->
```

- [ ] **Step 3: Commit**

```bash
git add .github/ISSUE_TEMPLATE
git commit -m "docs: GitHub 이슈 템플릿 추가"
```

---

## Task 8: `CHANGELOG.md`

**Files:**
- Create: `CHANGELOG.md`

- [ ] **Step 1: 작성 (Keep a Changelog 형식)**

```markdown
# Changelog

이 프로젝트의 주요 변경 사항을 기록합니다.
형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/),
버전은 [Semantic Versioning](https://semver.org/lang/ko/)을 따릅니다.

## [1.0.0] - 2026-06-01

### Added
- 한 줄 설치 `install.sh` (Finder 우클릭 메뉴 + CLI 동시 설치) 및 `uninstall.sh`.
- Quick Action 빌더 `build-workflow.sh` — `nfd2nfc` 본문을 임베드하는 단일 원본 구조.
- `--version` / `-V` 플래그.
- 통합 테스트 `test.sh` 및 GitHub Actions CI/릴리스 워크플로.
- Homebrew formula.

### Fixed
- **핵심 버그**: macOS 정규화 비구분 파일시스템에서 충돌 검사(`-e`)가 NFD 파일을
  자기 자신과 충돌로 오인해 모든 변환을 건너뛰던 문제. inode 비교로 교체.

[1.0.0]: https://github.com/wonjun-lab/nfd2nfc/releases/tag/v1.0.0
```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: CHANGELOG 추가 (v1.0.0)"
```

---

## Task 9: `CONTRIBUTING.md`

**Files:**
- Create: `CONTRIBUTING.md`

- [ ] **Step 1: 작성**

````markdown
# 기여 가이드

## 개발

`nfd2nfc`(perl)가 단일 원본입니다. Quick Action과 설치 스크립트는 이 파일을 임베드/참조합니다.

- 코어 수정: `nfd2nfc`
- Quick Action 재생성: `./build-workflow.sh` (→ `NFC로 이름 정리.workflow.zip`)
- 설치/제거: `./install.sh`, `./uninstall.sh`

## 테스트

```sh
./test.sh        # 통합 테스트 (macOS 전용 — APFS 정규화 비구분 동작에 의존)
shellcheck install.sh uninstall.sh build-workflow.sh test.sh
perl -c nfd2nfc
```

CI(`.github/workflows/ci.yml`)가 macOS에서 위를 자동 실행합니다.

## 릴리스 절차

1. `nfd2nfc`의 `$VERSION`과 `CHANGELOG.md`를 새 버전으로 갱신, 커밋.
2. 태그 푸시: `git tag vX.Y.Z && git push origin vX.Y.Z`.
3. `release.yml`이 Quick Action zip을 빌드해 GitHub Release에 첨부.
4. Homebrew tap 갱신: 릴리스 tarball의 sha256을 구해 `wonjun-lab/homebrew-tap`의
   `Formula/nfd2nfc.rb`(이 리포 `nfd2nfc.rb`가 원본)의 `url`/`sha256`을 갱신·커밋.
   ```sh
   curl -sL https://github.com/wonjun-lab/nfd2nfc/archive/refs/tags/vX.Y.Z.tar.gz | shasum -a 256
   ```
````

- [ ] **Step 2: Commit**

```bash
git add CONTRIBUTING.md
git commit -m "docs: 기여·테스트·릴리스 가이드 추가"
```

---

## Task 10: `README.md` 다듬기

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 상단 배지 추가**

기존 제목 `# nfd2nfc` 바로 아래(첫 설명 문단 앞)에 배지 줄 삽입:

```markdown
![CI](https://github.com/wonjun-lab/nfd2nfc/actions/workflows/ci.yml/badge.svg)
![Version](https://img.shields.io/github/v/tag/wonjun-lab/nfd2nfc?label=version)
![License](https://img.shields.io/badge/license-MIT-blue)
```

- [ ] **Step 2: 데모 자리 + Homebrew 설치법 추가**

`## 왜 필요한가` 앞에 데모 플레이스홀더 삽입:

```markdown
<!-- 데모 GIF: docs/demo.gif (추후 추가) -->
```

기존 `## 설치 — 한 줄 설치 (추천)` 섹션 **앞에** Homebrew 경로를 추가:

```markdown
## 설치 — Homebrew (CLI)

```sh
brew install wonjun-lab/tap/nfd2nfc
```

CLI `nfd2nfc` 명령을 설치합니다. Finder 우클릭 메뉴까지 원하면 아래 `install.sh`를 쓰세요.
```

- [ ] **Step 3: Finder zip 다운로드 출처를 Releases로 변경**

`## 설치 — Finder 우클릭 메뉴만 (터미널 없이)` 섹션의 1번 항목을 교체:

```markdown
1. [Releases](https://github.com/wonjun-lab/nfd2nfc/releases) 페이지에서
   `NFC로 이름 정리.workflow.zip`을 내려받아 압축을 풉니다.
```

- [ ] **Step 4: 옵션 표에 `-V` 추가**

기존 옵션 표의 `-h, --help` 행 위에 추가:

```markdown
| `-V`, `--version` | 버전 출력 |
```

- [ ] **Step 5: 영문 요약 섹션을 문서 끝(License 앞)에 추가**

```markdown
## English

**nfd2nfc** fixes macOS NFD filenames (e.g. Korean `안녕` showing as `ㅇㅏㄴㄴㅕㅇ`
on Windows / web uploads) by normalizing file & folder names to NFC. Zero dependencies
— uses the `perl` already on macOS.

- **Homebrew:** `brew install wonjun-lab/tap/nfd2nfc`
- **One-line install (CLI + Finder Quick Action):** `./install.sh`
- **Finder-only (no terminal):** download the `.workflow.zip` from
  [Releases](https://github.com/wonjun-lab/nfd2nfc/releases) and double-click.

CLI: `nfd2nfc [--dry-run] [--no-recurse] [--notify] [-v] [-V] <paths...>`
```

- [ ] **Step 6: 확인 후 Commit**

Run: `grep -n "badge.svg\|homebrew-tap\|## English\|github/v/tag" README.md`
Expected: 추가한 항목들이 보임.

```bash
git add README.md
git commit -m "docs: README 배지·Homebrew·영문·버전 옵션 반영"
```

---

## Self-Review 결과

**Spec coverage:** 구조정리(T3) · `--version`(T2) · `test.sh`(T1) · Homebrew(T4) ·
CI(T5) · release(T6) · 이슈템플릿(T7) · CHANGELOG(T8) · CONTRIBUTING(T9) · README(T10)
— 스펙 전 항목이 태스크에 매핑됨. (`--on-conflict`는 설계 변경으로 제외.)

**Placeholder scan:** Homebrew `sha256`은 릴리스 후 채우는 실제 절차(코드 placeholder 아님,
CONTRIBUTING에 방법 명시). 데모 GIF는 의도된 후속. 그 외 TBD/TODO 없음.

**Type consistency:** `$VERSION`/`$version` 명칭 일관. `--version|V` 단일 정의.
T1의 헬퍼(`count_nfd`, `make_fixture`)를 T2가 재사용 — 시그니처 일치.

**의존성 주의:** Task 1의 `test.sh`는 `build-workflow.sh`와 `install.sh`가 이미 존재함을
전제(현재 리포에 있음). Task 3에서 zip을 git에서 빼도 `test.sh`는 매 실행 시 직접 빌드하므로
무관.
