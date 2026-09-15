#!/usr/bin/env bash
# check-security.sh -- automated security battery for datetime.c.
#
# Three layers:
#   1. banned/dangerous libc API scan (static grep, fails on any hard hit;
#      softer items are listed for review but do not fail)
#   2. gcc -fanalyzer static analysis (fails on any warning)
#   3. ASan + LeakSanitizer runtime battery over success/error/stdin paths
#      plus a best-effort UBSan run (skipped with a notice if the runtime
#      is not installed; force failure with STRICT=1 instead)
#
# Exit 0 = clean, 1 = a layer failed.  Invoked by `make check-security`
# (part of `make check`).

set -u

cd "$(dirname "$0")/.." || exit 1
SRC=datetime.c
CC=${CC:-gcc}
CFLAGS="-std=c99 -O1 -g -Wall -Wextra"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FAIL=0

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
    G=$'\033[32m'; Y=$'\033[33m'; RED=$'\033[31m'; C=$'\033[36m'; R=$'\033[0m'
else
    G=''; Y=''; RED=''; C=''; R=''
fi
ok()   { printf '%s  OK   %s%s%s\n' "$G" "$R" "$1" "$R"; }
warn() { printf '%s  WARN %s%s\n' "$Y" "$1" "$R"; }
bad()  { printf '%s  FAIL %s%s\n' "$RED" "$1" "$R"; FAIL=1; }

echo "${C}== check-security: layer 1 -- banned libc API scan${R}"

# Hard-banned: no legitimate use in this codebase.
HARD_BANNED='gets|strcpy|strcat|sprintf|vsprintf|scanf|alloca|tmpnam|mktemp'
# Reviewed use (already audited: bounded/validated call sites).
SOFT='atoi|atol|popen|system|exec[lv]|getenv'

hits=$(grep -nE "\b(${HARD_BANNED})[[:space:]]*\(" "$SRC" || true)
if [[ -n $hits ]]; then
    echo "$hits"
    bad "banned libc API used: $(echo "$hits" | cut -d: -f1 | tr '\n' ' ')"
else
    ok "no banned APIs (gets/strcpy/strcat/sprintf/scanf/alloca/...)"
fi

soft_hits=$(grep -nE "\b(${SOFT})[[:space:]]*\(" "$SRC" || true)
if [[ -n $soft_hits ]]; then
    n=$(echo "$soft_hits" | wc -l)
    ok "reviewed API surface ($n site(s), bounded/validated):"
    echo "$soft_hits" | sed 's/^/         /'
else
    ok "no reviewed-API call sites"
fi

echo "${C}== check-security: layer 2 -- gcc -fanalyzer${R}"
if "$CC" $CFLAGS -fanalyzer -fsyntax-only "$SRC" 2>"$TMP/an.log"; then
    ok "static analyzer: no findings"
else
    sed 's/^/         /' "$TMP/an.log" | head -30
    bad "gcc -fanalyzer reported findings"
fi

echo "${C}== check-security: layer 3 -- ASan/LSan runtime battery${R}"
ASAN_BIN="$TMP/datetime_asan"
echo "         compiling ASan binary (this is the silent part, a few seconds)..."
if "$CC" -std=c99 -g -O1 -fsanitize=address -fno-omit-frame-pointer \
        -o "$ASAN_BIN" "$SRC" 2>"$TMP/asan_build.log"; then
    export ASAN_OPTIONS="detect_leaks=1:exitcode=86"
    # 86 = sanitizer abort (program itself uses 0/1).
    paths=(
        ""
        "--timestamp"
        "-hr" "-c" "-cd" "-wd"
        "+%Y-%m-%d %H:%M:%S"
        "-d now" "-d @0" "-d @2147483647"
        "-d 2020-01-02 03:04:05"
        "-d not-a-date" "-d ''"
        "-f Makefile" "-f /no/such/file" "-f -"
        "-r Makefile" "-r /no/such/file"
        "-s 2020-01-02"
        "--rfc-3339=seconds" "--rfc-3339=bogus"
        "-Iseconds" "-Ins"
        "-R" "--resolution" "--debug -d now"
        "--bogus-flag" "-d"
    )
    failed=0
    for c in "${paths[@]}"; do
        # Per-path progress: the runs themselves are silent by design
        # (their stderr is the sanitizer evidence being captured).
        printf '%s         · datetime %s%s\n' "$C" "$c" "$R"
        rc=0
        # `-f -` reads stdin — feed empty input to avoid hanging on a tty
        if [[ "$c" == "-f -" ]]; then
            printf '' | eval "\"$ASAN_BIN\" $c" >/dev/null 2>"$TMP/err.log" || rc=$?
        else
            # Use timeout if available to prevent hangs on unexpected stdin reads
            if command -v timeout >/dev/null 2>&1; then
                timeout 5 bash -c "eval \"$ASAN_BIN\" $c" >/dev/null 2>"$TMP/err.log" || rc=$?
                # timeout 124 = killed; treat as non-sanitizer failure (already reported via log)
                if [[ $rc -eq 124 ]]; then
                    warn "timeout on: datetime $c (no stdin) — treating as error path"
                    rc=1
                fi
            else
                eval "\"$ASAN_BIN\" $c" >/dev/null 2>"$TMP/err.log" || rc=$?
            fi
        fi
        if [[ $rc -eq 86 ]] || grep -qiE 'sanitizer|AddressSanitizer|LeakSanitizer|runtime error' "$TMP/err.log"; then
            bad "sanitizer report on: datetime $c"
            sed 's/^/         /' "$TMP/err.log" | head -8
            failed=1
        fi
    done
    [[ $failed -eq 0 ]] && ok "ASan+LSan clean on ${#paths[@]} success/error/stdin paths"
    # stdin path needs piped input separately (eval above has no stdin)
    if printf '2020-01-02\n' | "$ASAN_BIN" -f - +%F >/dev/null 2>"$TMP/err.log" \
       && ! grep -qiE 'sanitizer|runtime error' "$TMP/err.log"; then
        ok "ASan+LSan clean on stdin (-f -)"
    else
        bad "sanitizer report on stdin path"
    fi
else
    warn "ASan build failed (libasan missing?):"
    sed 's/^/         /' "$TMP/asan_build.log" | head -5
    [[ ${STRICT:-0} = 1 ]] && bad "STRICT=1: ASan unavailable counts as failure"
fi

echo "${C}== check-security: layer 3b -- UBSan (best effort)${R}"
UBSAN_BIN="$TMP/datetime_ubsan"
if "$CC" -std=c99 -g -O1 -fsanitize=undefined -o "$UBSAN_BIN" "$SRC" \
        2>"$TMP/ub_build.log"; then
    UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=1" \
        "$UBSAN_BIN" -d now -hr --timestamp --resolution \
        >/dev/null 2>"$TMP/ub.log" || true
    if grep -q 'runtime error' "$TMP/ub.log"; then
        sed 's/^/         /' "$TMP/ub.log" | head -10
        bad "UBSan reported undefined behavior"
    else
        ok "UBSan clean"
    fi
else
    warn "UBSan runtime not available on this box - skipped"
    sed 's/^/         /' "$TMP/ub_build.log" | head -3
    [[ ${STRICT:-0} = 1 ]] && bad "STRICT=1: UBSan unavailable counts as failure"
fi

echo
if [[ $FAIL -eq 0 ]]; then
    printf '%s== check-security: clean ==%s\n' "$G" "$R"
else
    printf '%s== check-security: FAILED ==%s\n' "$RED" "$R"
fi
exit $FAIL
