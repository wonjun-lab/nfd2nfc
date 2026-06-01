#!/bin/sh
#
# uninstall.sh — nfd2nfc 제거
#
#   ./uninstall.sh
#
set -eu

WORKFLOW_NAME="NFC로 이름 정리"
SERVICES_DIR="$HOME/Library/Services"

echo "▸ nfd2nfc 제거를 시작합니다."

# 1) Quick Action 제거
WF="$SERVICES_DIR/$WORKFLOW_NAME.workflow"
if [ -d "$WF" ]; then
    rm -rf "$WF"
    echo "  ✓ Finder 우클릭 메뉴 제거: $WF"
    /System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
    /System/Library/CoreServices/pbs -flush  >/dev/null 2>&1 || true
else
    echo "  - Quick Action 없음(건너뜀)"
fi

# 2) CLI 제거 (설치 가능 위치들 점검)
removed_cli=0
for BIN_DIR in /usr/local/bin "$HOME/.local/bin"; do
    if [ -f "$BIN_DIR/nfd2nfc" ]; then
        rm -f "$BIN_DIR/nfd2nfc" && echo "  ✓ CLI 제거: $BIN_DIR/nfd2nfc" && removed_cli=1
    fi
done
[ "$removed_cli" -eq 0 ] && echo "  - CLI 없음(건너뜀)"

echo
echo "✅ 제거 완료."
