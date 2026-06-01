#!/bin/sh
#
# install.sh — nfd2nfc 설치 (한 줄로 끝)
#
#   ./install.sh
#
# 하는 일:
#   1) Finder 우클릭 메뉴(Quick Action) "NFC로 이름 정리"를 ~/Library/Services 에 설치
#      → 더블클릭·보안 승인 없이 즉시 Finder 우클릭 메뉴에 나타남
#   2) CLI `nfd2nfc` 명령을 PATH(/usr/local/bin 또는 ~/.local/bin)에 설치
#
# 제거: ./uninstall.sh
#
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
WORKFLOW_NAME="NFC로 이름 정리"
SERVICES_DIR="$HOME/Library/Services"
SCRIPT_SRC="$HERE/nfd2nfc"

[ -f "$SCRIPT_SRC" ] || { echo "오류: $SCRIPT_SRC 가 없습니다."; exit 1; }

echo "▸ nfd2nfc 설치를 시작합니다."

# ── 1) Finder Quick Action 설치 ────────────────────────────────────────────
# build-workflow.sh의 빌더로 현재 스크립트를 임베드한 번들을 곧바로 Services에 생성.
# shellcheck source=build-workflow.sh
. "$HERE/build-workflow.sh"
mkdir -p "$SERVICES_DIR"
build_workflow_bundle "$SERVICES_DIR/$WORKFLOW_NAME.workflow"
echo "  ✓ Finder 우클릭 메뉴 설치: $SERVICES_DIR/$WORKFLOW_NAME.workflow"

# Quick Action이 메뉴에 즉시 보이도록 서비스 캐시 갱신 + Finder 재시작(실패해도 무방).
# Finder를 재시작하지 않으면 새 빠른 동작이 우클릭 메뉴에 바로 안 뜬다.
/System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
/System/Library/CoreServices/pbs -flush  >/dev/null 2>&1 || true
killall Finder >/dev/null 2>&1 || true   # 메뉴 갱신용 (Finder가 즉시 다시 뜸)

# ── 2) CLI 설치 ────────────────────────────────────────────────────────────
# /usr/local/bin 이 쓰기 가능하면 거기에, 아니면 ~/.local/bin 에 설치(둘 다 sudo 불필요).
if [ -w /usr/local/bin ] 2>/dev/null; then
    BIN_DIR=/usr/local/bin
elif [ -d /usr/local/bin ] && mkdir -p /usr/local/bin 2>/dev/null && [ -w /usr/local/bin ]; then
    BIN_DIR=/usr/local/bin
else
    BIN_DIR="$HOME/.local/bin"
fi
mkdir -p "$BIN_DIR"
install -m 0755 "$SCRIPT_SRC" "$BIN_DIR/nfd2nfc"
echo "  ✓ CLI 설치: $BIN_DIR/nfd2nfc"

# PATH 안내
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;  # 이미 PATH에 있음
    *)
        echo
        echo "  ⚠ $BIN_DIR 가 PATH에 없습니다. 아래 줄을 ~/.zshrc 에 추가하세요:"
        echo "      export PATH=\"$BIN_DIR:\$PATH\""
        ;;
esac

cat <<DONE

✅ 설치 완료!

사용법:
  • Finder에서 파일·폴더 우클릭 → "빠른 동작(Quick Actions)" 하위 메뉴
    → "NFC로 이름 정리".  (Finder를 방금 새로고침했으니 바로 보입니다.)
  • 터미널:  nfd2nfc ~/Downloads/내폴더
             nfd2nfc --dry-run ~/Desktop/*.hwp   (미리보기)

메뉴가 그래도 안 보이면:
  1) 우클릭 메뉴 맨 아래 "빠른 동작 ▸" 하위에 있는지 확인하세요.
  2) 시스템 설정 → 키보드 → 키보드 단축키 → 서비스 →
     "파일 및 폴더" 항목에서 "NFC로 이름 정리"가 체크돼 있는지 확인.
  3) 그래도 없으면 로그아웃 후 다시 로그인하면 확실히 등록됩니다.

제거하려면:  ./uninstall.sh
DONE
