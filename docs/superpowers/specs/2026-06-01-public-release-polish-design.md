# nfd2nfc 공개 릴리스 다듬기 + 편의 기능 — 설계

날짜: 2026-06-01
상태: 승인 대기

## 목표

`nfd2nfc`를 일반 공개 릴리스(v1.0.0) 품질로 다듬는다. 저장소를 정리하고,
버전 체계·CI·문서·기여 메타를 갖추며, 편의 기능으로 Homebrew 설치를 추가한다.

> **설계 변경(2026-06-01):** 당초 `--on-conflict` 옵션을 포함했으나, 검증 결과 macOS
> 정규화 비구분 FS에서는 제자리 정규화 시 대상 NFC 이름이 항상 원본과 같은 inode라
> "진짜 충돌"이 발생할 수 없어(수도코드·테스트 불가) **기능을 제외**했다.

## 비범위 (YAGNI)

- 변경 로그/`--undo` 되돌리기 — 사용자 제외
- 역방향 NFC→NFD — 수요 낮음
- 폴더 감시(launchd watch), 드래그앤드롭 .app — Quick Action으로 충분
- Homebrew tap 리포 자동 동기화 — 1회성 수동 설정으로 충분

## 저장소 구조 (평면 루트 + GitHub 강제 규약 .github/)

```
nfd2nfc                 # CLI 코어
install.sh              # 한 줄 설치 (Quick Action + CLI)
uninstall.sh            # 제거
build-workflow.sh       # Quick Action(.workflow) 빌더 — nfd2nfc 임베드, 단일 원본
test.sh                 # 통합 테스트 (수동 검증을 스크립트화, 로컬·CI 공용)
nfd2nfc.rb              # Homebrew formula (canonical 원본)
README.md  CHANGELOG.md  CONTRIBUTING.md  LICENSE  .gitignore
.github/workflows/ci.yml
.github/workflows/release.yml
.github/ISSUE_TEMPLATE/bug_report.md
.github/ISSUE_TEMPLATE/feature_request.md
```

**제거**: `NFC로 이름 정리.workflow.zip`을 `git rm`하고 `.gitignore`에 추가한다.
이 zip은 `build-workflow.sh`가 매번 다른 바이트로 재생성하는 비결정적 빌드 산출물이라
버전 관리 대상이 아니다. 릴리스 시 CI가 빌드해 GitHub Release 자산으로 첨부한다.

## 컴포넌트별 설계

### 1. `nfd2nfc` — 버전 플래그

- 스크립트 상단에 `my $VERSION = "1.0.0";` 단일 출처.
- `-V` / `--version` → `nfd2nfc 1.0.0` 출력 후 종료(0).
- 릴리스 태그(`vX.Y.Z`)와 수동 동기. 릴리스 절차를 CONTRIBUTING/CHANGELOG에 문서화.
- GetOptions에 `'version|V' => \$version` 추가, `usage` 위에서 처리.

### 2. `test.sh` — 통합 테스트

- 검증된 수동 테스트를 스크립트화. macOS(APFS)에서만 의미 있음.
- 케이스: 기본 NFD→NFC 변환, 중첩 폴더, idempotent 재실행, dry-run 무변경,
  `--no-recurse`, 심볼릭 링크 미추적, `--version`,
  생성된 Quick Action 명령(임시파일·stdin 두 모드) 실행.
- 각 케이스 통과/실패를 출력하고 실패 시 비0 종료(CI 게이트).
- 임시 작업 디렉토리(`mktemp -d`) 사용, 종료 시 정리.

### 3. `nfd2nfc.rb` — Homebrew formula

- 의존성 없는 단일 perl 스크립트 → `bin.install "nfd2nfc"`.
- `url`은 GitHub 태그 tarball, `sha256`은 릴리스 후 채움(릴리스 절차에 명시).
- `test do` 블록: `assert_match "nfd2nfc", shell_output("#{bin}/nfd2nfc --version")`.
- 배포는 별도 `wonjun-lab/homebrew-tap` 리포 필요. 이 파일은 원본이며,
  릴리스마다 tap 리포로 복사·`sha256` 갱신(README/CONTRIBUTING에 문서화).

### 4. CI — `.github/workflows/ci.yml`

- 트리거: push, pull_request.
- 러너: **macos-latest** (정규화 비구분 FS 동작 검증 필수).
- 단계: `perl -c nfd2nfc` → `shellcheck install.sh uninstall.sh build-workflow.sh test.sh`
  → `./test.sh`.
- shellcheck는 `brew install shellcheck`로 설치(또는 사전설치 확인).

### 5. 릴리스 — `.github/workflows/release.yml`

- 트리거: `v*` 태그 push.
- 러너: macos-latest.
- 단계: `./build-workflow.sh`로 zip 빌드 → `gh release create <tag> <zip> --generate-notes`
  또는 `softprops/action-gh-release`로 zip 첨부.
- 권한: `contents: write`.

### 6. 문서/메타

- **README**: 영문 섹션 정리, 배지(license·CI·version), 설치 경로 3종 명시
  (Homebrew / install.sh / Releases zip), 데모 GIF 플레이스홀더.
- **CHANGELOG.md**: Keep a Changelog 형식. v1.0.0 항목 = NFD→NFC 충돌검사 버그 수정,
  한 줄 설치, Quick Action 빌더, `--version`.
- **CONTRIBUTING.md**: 개발·테스트(`./test.sh`)·릴리스 절차(태그→CI→tap 갱신).
- **이슈 템플릿**: bug_report, feature_request.

## 데이터 흐름 / 일관성

- `nfd2nfc`가 유일 원본. `build-workflow.sh`가 그 본문을 Quick Action에 임베드,
  `install.sh`가 `build-workflow.sh`를 source, `test.sh`가 둘 다 검증, CI가 `test.sh` 실행.
  → 스크립트를 고치면 모든 산출물이 자동 동기, 빌드 산출물은 커밋하지 않는다.

## 테스트 전략

- `test.sh`가 단일 진실 공급원. 로컬에서 `./test.sh`, CI에서 동일 실행.
- 실패 케이스는 명확한 메시지 + 비0 종료.

## 버전

- 첫 공개 릴리스: **v1.0.0** (도구가 실제로 동작하는 첫 신뢰 버전).
