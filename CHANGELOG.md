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
