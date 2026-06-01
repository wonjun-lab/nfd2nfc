#!/bin/sh
#
# build-workflow.sh — `nfd2nfc` 스크립트로부터 Finder Quick Action(.workflow)을 생성한다.
#
# Quick Action 안에는 `nfd2nfc` 본문이 그대로 임베드된다(heredoc으로 perl에 전달).
# 즉 스크립트가 유일한 원본(single source of truth)이며, 이 빌더가 항상 동기화한다.
#
# 사용법:
#   ./build-workflow.sh                 # 저장소 루트에 .workflow 빌드 후 zip 재생성
#   . ./build-workflow.sh; build_workflow_bundle <대상.workflow 경로>   # 함수만 사용
#
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT_SRC="$HERE/nfd2nfc"
WORKFLOW_NAME="NFC로 이름 정리"

# build_workflow_bundle <bundle_path>
# 주어진 경로에 완전한 .workflow 번들을 만든다(스크립트 본문 임베드).
build_workflow_bundle() {
    bundle="$1"
    rm -rf "$bundle"
    mkdir -p "$bundle/Contents"

    # document.wflow 생성: 스크립트 본문을 heredoc 명령으로 감싸 XML 이스케이프 후 삽입.
    # 생성기 perl은 셸 heredoc(<<'GENWFLOW')으로 전달하므로 셸 따옴표 충돌이 없다.
    SCRIPT_SRC="$SCRIPT_SRC" /usr/bin/perl > "$bundle/Contents/document.wflow" <<'GENWFLOW'
        my $src = $ENV{SCRIPT_SRC};
        open(my $fh, "<", $src) or die "스크립트를 열 수 없음: $src\n";
        local $/; my $body = <$fh>; close $fh;

        # Quick Action이 실행할 셸 명령:
        #   perl이 스크립트를 stdin(heredoc)으로 읽고, 선택된 파일들을 인자("$@")로 받는다.
        #   프로그램이 셸 명령줄이 아니라 heredoc 본문에 있으므로 셸 따옴표/이스케이프가 불필요.
        my $cmd = qq{/usr/bin/perl - --notify -- "\$\@" <<'NFD2NFC_EOF'\n}
                . $body
                . qq{NFD2NFC_EOF\n};

        # plist <string> 안에 들어가므로 XML 특수문자 이스케이프
        my $esc = $cmd;
        $esc =~ s/&/&amp;/g; $esc =~ s/</&lt;/g; $esc =~ s/>/&gt;/g;

        print <<"WFLOW";
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>AMApplicationBuild</key>
\t<string>523</string>
\t<key>AMApplicationVersion</key>
\t<string>2.10</string>
\t<key>AMDocumentVersion</key>
\t<string>2</string>
\t<key>actions</key>
\t<array>
\t\t<dict>
\t\t\t<key>action</key>
\t\t\t<dict>
\t\t\t\t<key>AMAccepts</key>
\t\t\t\t<dict>
\t\t\t\t\t<key>Container</key>
\t\t\t\t\t<string>List</string>
\t\t\t\t\t<key>Optional</key>
\t\t\t\t\t<true/>
\t\t\t\t\t<key>Types</key>
\t\t\t\t\t<array>
\t\t\t\t\t\t<string>com.apple.cocoa.string</string>
\t\t\t\t\t</array>
\t\t\t\t</dict>
\t\t\t\t<key>AMActionVersion</key>
\t\t\t\t<string>2.0.3</string>
\t\t\t\t<key>AMApplication</key>
\t\t\t\t<array>
\t\t\t\t\t<string>Automator</string>
\t\t\t\t</array>
\t\t\t\t<key>AMParameterProperties</key>
\t\t\t\t<dict>
\t\t\t\t\t<key>COMMAND_STRING</key>
\t\t\t\t\t<dict/>
\t\t\t\t\t<key>CheckedForUserDefaultShell</key>
\t\t\t\t\t<dict/>
\t\t\t\t\t<key>inputMethod</key>
\t\t\t\t\t<dict/>
\t\t\t\t\t<key>shell</key>
\t\t\t\t\t<dict/>
\t\t\t\t\t<key>source</key>
\t\t\t\t\t<dict/>
\t\t\t\t</dict>
\t\t\t\t<key>AMProvides</key>
\t\t\t\t<dict>
\t\t\t\t\t<key>Container</key>
\t\t\t\t\t<string>List</string>
\t\t\t\t\t<key>Types</key>
\t\t\t\t\t<array>
\t\t\t\t\t\t<string>com.apple.cocoa.string</string>
\t\t\t\t\t</array>
\t\t\t\t</dict>
\t\t\t\t<key>ActionBundlePath</key>
\t\t\t\t<string>/System/Library/Automator/Run Shell Script.action</string>
\t\t\t\t<key>ActionName</key>
\t\t\t\t<string>Run Shell Script</string>
\t\t\t\t<key>ActionParameters</key>
\t\t\t\t<dict>
\t\t\t\t\t<key>COMMAND_STRING</key>
\t\t\t\t\t<string>$esc</string>
\t\t\t\t\t<key>CheckedForUserDefaultShell</key>
\t\t\t\t\t<true/>
\t\t\t\t\t<key>inputMethod</key>
\t\t\t\t\t<integer>1</integer>
\t\t\t\t\t<key>shell</key>
\t\t\t\t\t<string>/bin/zsh</string>
\t\t\t\t\t<key>source</key>
\t\t\t\t\t<string></string>
\t\t\t\t</dict>
\t\t\t\t<key>BundleIdentifier</key>
\t\t\t\t<string>com.apple.Automator.RunShellScript</string>
\t\t\t\t<key>CFBundleVersion</key>
\t\t\t\t<string>2.0.3</string>
\t\t\t\t<key>CanShowSelectedItemsWhenRun</key>
\t\t\t\t<false/>
\t\t\t\t<key>CanShowWhenRun</key>
\t\t\t\t<true/>
\t\t\t\t<key>Category</key>
\t\t\t\t<array>
\t\t\t\t\t<string>AMCategoryUtilities</string>
\t\t\t\t</array>
\t\t\t\t<key>Class Name</key>
\t\t\t\t<string>RunShellScriptAction</string>
\t\t\t\t<key>InputUUID</key>
\t\t\t\t<string>8BCDD556-B2E2-41A2-9964-05D3749FB662</string>
\t\t\t\t<key>Keywords</key>
\t\t\t\t<array>
\t\t\t\t\t<string>Shell</string>
\t\t\t\t\t<string>Script</string>
\t\t\t\t\t<string>Command</string>
\t\t\t\t\t<string>Run</string>
\t\t\t\t\t<string>Unix</string>
\t\t\t\t</array>
\t\t\t\t<key>OutputUUID</key>
\t\t\t\t<string>40B040EB-E7CB-4AEE-847A-4560B3267CFF</string>
\t\t\t\t<key>UUID</key>
\t\t\t\t<string>997345B7-856E-4FBB-B773-B9E3076912CC</string>
\t\t\t\t<key>UnlocalizedApplications</key>
\t\t\t\t<array>
\t\t\t\t\t<string>Automator</string>
\t\t\t\t</array>
\t\t\t\t<key>arguments</key>
\t\t\t\t<dict/>
\t\t\t\t<key>isViewVisible</key>
\t\t\t\t<true/>
\t\t\t\t<key>location</key>
\t\t\t\t<string>449.000000:253.000000</string>
\t\t\t\t<key>nibPath</key>
\t\t\t\t<string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/main.nib</string>
\t\t\t</dict>
\t\t\t<key>isViewVisible</key>
\t\t\t<true/>
\t\t\t<key>location</key>
\t\t\t<string>449.000000:253.000000</string>
\t\t\t<key>nibPath</key>
\t\t\t<string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/main.nib</string>
\t\t</dict>
\t</array>
\t<key>connectors</key>
\t<dict/>
\t<key>workflowMetaData</key>
\t<dict>
\t\t<key>applicationBundleIDsByPath</key>
\t\t<dict/>
\t\t<key>applicationPaths</key>
\t\t<array/>
\t\t<key>inputTypeIdentifier</key>
\t\t<string>com.apple.Automator.fileSystemObject</string>
\t\t<key>outputTypeIdentifier</key>
\t\t<string>com.apple.Automator.nothing</string>
\t\t<key>presentationMode</key>
\t\t<integer>11</integer>
\t\t<key>processesInput</key>
\t\t<integer>0</integer>
\t\t<key>serviceApplicationBundleID</key>
\t\t<string></string>
\t\t<key>serviceInputTypeIdentifier</key>
\t\t<string>com.apple.Automator.fileSystemObject</string>
\t\t<key>serviceOutputTypeIdentifier</key>
\t\t<string>com.apple.Automator.nothing</string>
\t\t<key>useAutomaticInputType</key>
\t\t<integer>0</integer>
\t\t<key>workflowTypeIdentifier</key>
\t\t<string>com.apple.Automator.servicesMenu</string>
\t</dict>
</dict>
</plist>
WFLOW
GENWFLOW

    # Info.plist 생성 (Quick Action 메뉴 등록 정보)
    WORKFLOW_NAME="$WORKFLOW_NAME" /usr/bin/perl > "$bundle/Contents/Info.plist" <<'GENPLIST'
        my $name = $ENV{WORKFLOW_NAME};
        $name =~ s/&/&amp;/g; $name =~ s/</&lt;/g; $name =~ s/>/&gt;/g;
        print <<"PLIST";
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>CFBundleName</key>
\t<string>$name</string>
\t<key>CFBundleIdentifier</key>
\t<string>com.wonjun-lab.nfd2nfc.quickaction</string>
\t<key>NSServices</key>
\t<array>
\t\t<dict>
\t\t\t<key>NSMenuItem</key>
\t\t\t<dict>
\t\t\t\t<key>default</key>
\t\t\t\t<string>$name</string>
\t\t\t</dict>
\t\t\t<key>NSMessage</key>
\t\t\t<string>runWorkflowAsService</string>
\t\t\t<key>NSSendFileTypes</key>
\t\t\t<array>
\t\t\t\t<string>public.item</string>
\t\t\t</array>
\t\t</dict>
\t</array>
</dict>
</plist>
PLIST
GENPLIST
}

# 직접 실행되면: 저장소에 .workflow 빌드 후 zip 재생성
if [ "${0##*/}" = "build-workflow.sh" ]; then
    BUNDLE="$HERE/$WORKFLOW_NAME.workflow"
    build_workflow_bundle "$BUNDLE"
    # plist 유효성 검사
    /usr/bin/plutil -lint "$BUNDLE/Contents/document.wflow" >/dev/null
    /usr/bin/plutil -lint "$BUNDLE/Contents/Info.plist" >/dev/null
    # zip 재생성
    ( cd "$HERE" && rm -f "$WORKFLOW_NAME.workflow.zip" \
        && /usr/bin/zip -r -q "$WORKFLOW_NAME.workflow.zip" "$WORKFLOW_NAME.workflow" )
    rm -rf "$BUNDLE"
    echo "빌드 완료: $WORKFLOW_NAME.workflow.zip"
fi
