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
if [ "$(count_nfd "$TMP/t1")" -eq 0 ]; then ok "기본 변환(중첩 포함) 전부 NFC"; else ng "기본 변환 실패"; fi

# [2] idempotent: 재실행 0개 변경
out=$(/usr/bin/perl "$NFD2NFC" "$TMP/t1" 2>&1)
if echo "$out" | grep -q "0개 변경"; then ok "idempotent 재실행 0개 변경"; else ng "idempotent 실패: $out"; fi

# [3] dry-run: 변경 없음
make_fixture "$TMP/t3"
/usr/bin/perl "$NFD2NFC" --dry-run "$TMP/t3" >/dev/null 2>&1
if [ "$(count_nfd "$TMP/t3")" -eq 3 ]; then ok "dry-run은 실제 변경 안 함"; else ng "dry-run이 파일을 변경함"; fi

# [4] --no-recurse: 지정 폴더만, 하위는 유지
make_fixture "$TMP/t4"
sub=$(/usr/bin/perl -e 'opendir(my$d,$ARGV[0]);for(readdir$d){next if/^\.\.?$/;next unless -d "$ARGV[0]/$_";print "$ARGV[0]/$_";last}' "$TMP/t4")
/usr/bin/perl "$NFD2NFC" --no-recurse "$sub" >/dev/null 2>&1
if [ "$(count_nfd "$TMP/t4")" -ge 1 ]; then ok "--no-recurse는 하위 미처리"; else ng "--no-recurse가 하위까지 처리함"; fi

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
if [ "$link_count" -eq 1 ] && [ "$(count_nfd "$TMP/t5")" -eq 0 ]; then ok "심볼릭 링크 미추적 + 이름만 정규화"; else ng "심볼릭 링크 처리 이상"; fi

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
if [ "$(count_nfd "$TMP/t6")" -eq 0 ]; then ok "Quick Action 명령 실행 변환 성공"; else ng "Quick Action 명령 변환 실패"; fi

echo "----"
echo "통과 $PASS / 실패 $FAIL"
[ "$FAIL" -eq 0 ]
