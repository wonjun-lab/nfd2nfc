#!/usr/bin/env bash
# test.sh — nfd2nfc 통합 테스트 (macOS/APFS 전용)
# 정규화 비구분 FS 동작에 의존하므로 반드시 macOS에서 실행.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
NFD2NFC="$HERE/nfd2nfc"
PASS=0
FAIL=0

# 테스트 중 osascript(Finder/알림) 부작용·AppleEvent 타임아웃을 차단한다.
# (Quick Action 명령은 항상 --reveal을 포함하므로 이 가드가 없으면 Finder가 튀어나오고
#  헤드리스 CI에서는 AppleEvent가 120초 타임아웃 날 수 있다.)
export NFD2NFC_NO_GUI=1

ok() { PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf '  \033[31m✗\033[0m %s\n' "$1"; }

# 디렉토리 아래 NFD로 남은 항목 수 출력(시작 디렉토리 자신은 제외)
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

# 단일 경로의 basename이 NFC면 exit 0, 아니면 exit 1 (디렉토리 비재귀)
is_nfc_base() {
    /usr/bin/perl -e '
        use Unicode::Normalize qw(NFC); use Encode qw(decode_utf8);
        my $p = $ARGV[0]; $p =~ s{/+$}{};
        my $i = rindex($p, "/"); my $b = $i < 0 ? $p : substr($p, $i + 1);
        my $u = eval { my $c = $b; decode_utf8($c, Encode::FB_CROAK) };
        exit((defined $u && NFC($u) eq $u) ? 0 : 1);
    ' "$1"
}

# t10 등에서 최상위 첫 (디렉토리|파일) 항목 경로를 출력
first_entry() {  # first_entry <base> <d|f>
    /usr/bin/perl -e '
        opendir(my $d, $ARGV[0]) or exit 0;
        for (sort readdir $d) {
            next if /^\.\.?$/;
            my $p = "$ARGV[0]/$_";
            if ($ARGV[1] eq "d") { next unless -d $p } else { next unless -f $p }
            print $p; last;
        }
    ' "$1" "$2"
}

# 표준 NFD 픽스처: <dir>/보고서.hwp, <dir>/하위폴더/사진.jpg
# use utf8: 소스의 한글 리터럴을 진짜 한글 코드포인트로 인식해야 한글 자모(U+11xx) NFD가
# 만들어진다. 빼면 UTF-8 바이트를 latin-1로 오인해 라틴 분해문자 NFD를 테스트하게 된다.
make_fixture() {
    base="$1"
    mkdir -p "$base"
    /usr/bin/perl -e '
        use utf8;
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

# [4] --no-recurse: 지정한 폴더 자신은 NFC로, 그 내부(사진.jpg)는 미처리로 남는다.
#     약한 단언(트리 전체 count>=1)은 옵션이 깨져도 통과하므로, 두 측면을 분리 단언한다.
make_fixture "$TMP/t4"
sub=$(first_entry "$TMP/t4" d)
if [ -z "$sub" ] || [ ! -d "$sub" ]; then
    ng "[4] 픽스처 하위폴더 탐색 실패(빈 경로)"
else
    /usr/bin/perl "$NFD2NFC" --no-recurse "$sub" >/dev/null 2>&1
    # 변환 후 하위폴더는 NFC명으로 바뀌므로 부모에서 다시 찾는다.
    subnfc=$(first_entry "$TMP/t4" d)
    inside_nfd=$(count_nfd "$subnfc")
    if is_nfc_base "$subnfc"; then base_ok=1; else base_ok=0; fi
    if [ "$base_ok" -eq 1 ] && [ "$inside_nfd" -eq 1 ]; then
        ok "--no-recurse: 폴더 자신만 NFC, 내부(사진.jpg) 미처리"
    else
        ng "--no-recurse 이상: 폴더basename NFC=$base_ok, 내부 NFD수=$inside_nfd (기대 1,1)"
    fi
fi

# [5] 심볼릭 링크 미추적
mkdir -p "$TMP/t5"
/usr/bin/perl -e '
    use utf8;
    use Unicode::Normalize qw(NFD); use Encode qw(encode_utf8);
    my $b = $ARGV[0];
    my $real = "$b/" . encode_utf8(NFD("실제폴더")); mkdir $real;
    symlink($real, "$b/" . encode_utf8(NFD("링크"))) or die "$!";
' "$TMP/t5"
/usr/bin/perl "$NFD2NFC" "$TMP/t5" >/dev/null 2>&1
link_count=$(/usr/bin/perl -e 'my$n=0;opendir(my$d,$ARGV[0]);for(readdir$d){next if/^\.\.?$/;$n++ if -l "$ARGV[0]/$_"}print$n' "$TMP/t5")
if [ "$link_count" -eq 1 ] && [ "$(count_nfd "$TMP/t5")" -eq 0 ]; then ok "심볼릭 링크 미추적 + 이름만 정규화"; else ng "심볼릭 링크 처리 이상"; fi

# [6] 생성된 Quick Action 명령 실행. 리포 루트 산출물을 건드리지 않게 함수 모드로 $TMP에 빌드한다.
# shellcheck source=build-workflow.sh
( . "$HERE/build-workflow.sh"; build_workflow_bundle "$TMP/qa.workflow" ) >/dev/null 2>&1
DOC="$TMP/qa.workflow/Contents/document.wflow"
if [ ! -f "$DOC" ]; then
    ng "[6] Quick Action 빌드 실패(document.wflow 없음)"
else
    /usr/bin/plutil -extract "actions.0.action.ActionParameters.COMMAND_STRING" raw -o "$TMP/qa_cmd.sh" "$DOC"
    make_fixture "$TMP/t6"
    /usr/bin/perl -e '
        my @a; opendir(my $d, $ARGV[1]); for (readdir $d) { next if /^\.\.?$/; push @a, "$ARGV[1]/$_" } closedir $d;
        system("/bin/zsh", $ARGV[0], @a);
    ' "$TMP/qa_cmd.sh" "$TMP/t6"
    if [ "$(count_nfd "$TMP/t6")" -eq 0 ]; then ok "Quick Action 명령 실행 변환 성공"; else ng "Quick Action 명령 변환 실패"; fi
fi

# [7] 종료 코드: 정상 변환은 0, 존재하지 않는 입력은 비0(자동화가 부분 실패를 감지 가능)
make_fixture "$TMP/t7"
/usr/bin/perl "$NFD2NFC" "$TMP/t7" >/dev/null 2>&1; rc_ok=$?
/usr/bin/perl "$NFD2NFC" "$TMP/없는경로_xyz" >/dev/null 2>&1; rc_missing=$?
if [ "$rc_ok" -eq 0 ] && [ "$rc_missing" -ne 0 ]; then ok "종료 코드: 정상 0 / 실패 비0"; else ng "종료 코드 이상: 정상=$rc_ok 실패=$rc_missing"; fi

# [8] inode 비교가 자기 자신을 충돌로 오인하지 않음 (1.0.0 핵심 버그의 회귀 가드).
#     '진짜 다른 inode가 NFC명을 점유'한 충돌은 APFS 정규화 비구분 특성상 단일 볼륨에서
#     재현 불가하므로, 그 반대(자기 자신 오인으로 전부 건너뛰는 회귀)를 막는다.
make_fixture "$TMP/t8"
err=$(/usr/bin/perl "$NFD2NFC" "$TMP/t8" 2>&1 >/dev/null)
if [ "$(count_nfd "$TMP/t8")" -eq 0 ] && ! printf '%s' "$err" | grep -q "건너뜀"; then
    ok "inode 자기오인 없음(전부 변환, 건너뜀 경고 0)"
else
    ng "inode 자기오인 의심(건너뜀 경고: $err)"
fi

# [9] 단문자 옵션 묶음(-nv == -n -v): dry-run+verbose로 동작하되 실제 변경은 없어야 함
make_fixture "$TMP/t9"
out=$(/usr/bin/perl "$NFD2NFC" -nv "$TMP/t9" 2>&1)
if echo "$out" | grep -q "미리보기" && [ "$(count_nfd "$TMP/t9")" -eq 3 ]; then ok "-nv 묶음(dry-run+verbose)"; else ng "-nv 묶음 이상: $out"; fi

# [10] 중복 입력은 한 번만 처리(카운트 부풀림·이중 rename 없음)
make_fixture "$TMP/t10"
f=$(first_entry "$TMP/t10" f)
out=$(/usr/bin/perl "$NFD2NFC" --no-recurse "$f" "$f" 2>&1)
if echo "$out" | grep -q "1개 변경"; then ok "중복 입력 dedup(1개 변경)"; else ng "중복 입력 dedup 실패: $out"; fi

# [11] --quiet: 요약 출력을 억제(stdout 비움)하되 변환은 정상 수행
make_fixture "$TMP/t11"
qout=$(/usr/bin/perl "$NFD2NFC" --quiet "$TMP/t11" 2>/dev/null)
if [ -z "$qout" ] && [ "$(count_nfd "$TMP/t11")" -eq 0 ]; then ok "--quiet: 무출력 + 변환 수행"; else ng "--quiet 이상(out=[$qout])"; fi

# [12] --force: 충돌 검사를 우회해도 일반 변환을 정상 수행하고 건너뜀 경고가 없어야 함.
#      (진짜 다른 inode가 NFC명을 점유한 충돌은 APFS 정규화 비구분 특성상 단일 볼륨에서 재현 불가)
make_fixture "$TMP/t12"
ferr=$(/usr/bin/perl "$NFD2NFC" --force "$TMP/t12" 2>&1 >/dev/null)
if [ "$(count_nfd "$TMP/t12")" -eq 0 ] && [ -z "$ferr" ]; then ok "--force: 정상 변환 + 경고 없음"; else ng "--force 이상(err=[$ferr])"; fi

# [13] 셸(zsh glob/탭완성)이 NFC로 정규화한 인자로도 디스크 NFD를 변환 (disk_real_path).
#      셸이 인자를 NFC로 넘기면 인자 basename은 NFC지만 디스크 엔트리는 NFD다.
D13="$TMP/t13"; mkdir -p "$D13"
/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);
  open(my$f,">",$ARGV[0]."/".encode_utf8(NFD("계약서.pdf")));close$f;' "$D13"
nfc_arg="$D13/$(/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFC);use Encode qw(encode_utf8);print encode_utf8(NFC("계약서.pdf"))')"
/usr/bin/perl "$NFD2NFC" "$nfc_arg" >/dev/null 2>&1
if [ "$(count_nfd "$D13")" -eq 0 ]; then ok "NFC 인자(셸 정규화)로도 디스크 NFD 변환"; else ng "disk_real_path 실패(NFC 인자 변환 누락)"; fi

# [14] NFC로 저장된 디스크 파일에 NFD 철자 인자 → 실제 변화 없으므로 '0개 변경'(거짓 카운트 방지)
D14="$TMP/t14"; mkdir -p "$D14"
printf x > "$D14/$(/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFC);use Encode qw(encode_utf8);print encode_utf8(NFC("문서.txt"))')"
nfd_arg="$D14/$(/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);print encode_utf8(NFD("문서.txt"))')"
out14=$(/usr/bin/perl "$NFD2NFC" "$nfd_arg" 2>&1)
if echo "$out14" | grep -q "0개 변경"; then ok "NFC 디스크 + NFD 인자 → 거짓 카운트 없음"; else ng "거짓 카운트: $out14"; fi

# [15] 같은 디스크 항목을 NFD/NFC 다른 철자로 중복 지정 → 카운트 부풀림·이중 처리 없음
D15="$TMP/t15"; mkdir -p "$D15"
/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);
  my$d=$ARGV[0];my$s="$d/".encode_utf8(NFD("폴더"));mkdir $s;
  open(my$f,">","$s/".encode_utf8(NFD("파일.txt")));close$f;' "$D15"
nfc_dir="$D15/$(/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFC);use Encode qw(encode_utf8);print encode_utf8(NFC("폴더"))')"
base15=$(/usr/bin/perl "$NFD2NFC" -n "$D15" 2>&1 | tail -1)
dup15=$(/usr/bin/perl "$NFD2NFC" -n "$D15" "$nfc_dir" 2>&1 | tail -1)
if [ "$base15" = "$dup15" ]; then ok "NFD/NFC 철자 중복 입력 dedup(카운트 안 부풀림)"; else ng "dedup 실패: base=[$base15] dup=[$dup15]"; fi

# [16] 압축 파일의 '내부' 엔트리명은 스코프 밖 — 외부 파일명만 정규화되고 내부·내용은 불변(한계 회귀 가드)
D16="$TMP/t16"; mkdir -p "$D16"
( cd "$D16" || exit
  inner=$(/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);print encode_utf8(NFD("안.txt"))')
  printf x > "$inner"
  arc=$(/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);print encode_utf8(NFD("자료.zip"))')
  zip -q "$arc" "$inner" && rm -f "$inner" )
entry_bytes() { /usr/bin/python3 -c '
import zipfile,glob,sys
z=glob.glob(sys.argv[1]+"/*.zip")[0]
i=zipfile.ZipFile(z).infolist()[0]
raw=i.filename.encode("utf-8") if (i.flag_bits & 0x800) else i.filename.encode("cp437")
print(raw.hex())' "$1"; }
before16=$(entry_bytes "$D16"); md5b16=$(md5 -q "$D16"/*.zip)
/usr/bin/perl "$NFD2NFC" -q "$D16"
after16=$(entry_bytes "$D16"); md5a16=$(md5 -q "$D16"/*.zip)
if [ "$before16" = "$after16" ] && [ "$md5b16" = "$md5a16" ]; then ok "압축 내부 엔트리명·내용 불변(스코프 밖)"; else ng "압축 내부 변함: name $before16→$after16"; fi

# [버전] --version 출력 형식
ver_out=$(/usr/bin/perl "$NFD2NFC" --version 2>&1)
if echo "$ver_out" | grep -Eq '^nfd2nfc [0-9]+\.[0-9]+\.[0-9]+$'; then ok "--version 출력 형식"; else ng "--version 형식 이상: $ver_out"; fi
# -V 단축 일치
v2=$(/usr/bin/perl "$NFD2NFC" -V 2>&1)
if [ "$v2" = "$ver_out" ]; then ok "-V 단축 일치"; else ng "-V 불일치: $v2"; fi
# 회귀 방지: 소문자 -v 는 verbose여야 하며 version으로 새면 안 됨
make_fixture "$TMP/tv"
vout=$(/usr/bin/perl "$NFD2NFC" -v "$TMP/tv" 2>&1)
if echo "$vout" | grep -q "변경:" && [ "$(count_nfd "$TMP/tv")" -eq 0 ]; then ok "-v 는 verbose(변환 수행)"; else ng "-v 가 verbose로 동작 안 함: $vout"; fi

echo "----"
echo "통과 $PASS / 실패 $FAIL"
[ "$FAIL" -eq 0 ]
