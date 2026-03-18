#!/usr/bin/env bash
# run_crosscheck_dotnet.sh — run snobol4corpus crosscheck rungs against DOTNET
#
# Usage: run_crosscheck_dotnet.sh [--filter PATTERN] [--corpus DIR] [--dotnet-repo DIR]
#
# Feeds .input files via stdin where present; diffs stdout against .ref oracle.
# Uses -b flag to suppress DOTNET sign-on banner; strips leading CWD line.
#
# Exit: 0 if all pass, 1 if any fail.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTNET_REPO="${DOTNET_REPO:-$HOME/snobol4dotnet}"
CORPUS="${CORPUS:-$HOME/snobol4corpus/crosscheck}"
FILTER="${FILTER:-}"
DOTNET_ROOT="${DOTNET_ROOT:-$HOME/.dotnet}"
export DOTNET_ROOT
export PATH="$PATH:$DOTNET_ROOT"

SNO4_DLL="$DOTNET_REPO/Snobol4/bin/Release/net10.0/Snobol4.dll"

# Colors
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; RESET='\033[0m'

PASS=0; FAIL=0; SKIP=0

if [[ ! -f "$SNO4_DLL" ]]; then
    echo "ERROR: Snobol4.dll not found at $SNO4_DLL"
    echo "Build with: cd $DOTNET_REPO && dotnet build Snobol4.sln -c Release -p:EnableWindowsTargeting=true"
    exit 1
fi

run_test() {
    local sno="$1"
    local ref="${sno%.sno}.ref"
    local input="${sno%.sno}.input"
    local name
    name=$(basename "$sno" .sno)

    [[ -n "$FILTER" && "$name" != *"$FILTER"* ]] && { SKIP=$((SKIP+1)); return; }
    [[ ! -f "$ref" ]] && { echo -e "${YELLOW}SKIP${RESET} $name (no .ref)"; SKIP=$((SKIP+1)); return; }

    # DOTNET quirk: program output goes to stderr; CWD line goes to stdout.
    # -b suppresses sign-on banner. Capture stderr; discard stdout.
    local got
    if [[ -f "$input" ]]; then
        got=$(timeout 10 dotnet "$SNO4_DLL" -b "$sno" < "$input" 2>&1 1>/dev/null || true)
    else
        got=$(timeout 10 dotnet "$SNO4_DLL" -b "$sno" 2>&1 1>/dev/null || true)
    fi

    local exp
    exp=$(cat "$ref")

    if [[ "$got" == "$exp" ]]; then
        echo -e "${GREEN}PASS${RESET} $name"
        PASS=$((PASS+1))
    else
        echo -e "${RED}FAIL${RESET} $name"
        diff <(echo "$exp") <(echo "$got") | head -8 | sed 's/^/      /'
        FAIL=$((FAIL+1))
    fi
}

echo "=== DOTNET crosscheck ==="
echo "dll:    $SNO4_DLL"
echo "corpus: $CORPUS"
echo ""

DIRS=(hello output assign concat arith_new control_new patterns capture strings functions data keywords
      rung2 rung3 rung4 rung8 rung9 rung10 rung11)

for dir in "${DIRS[@]}"; do
    full="$CORPUS/$dir"
    [[ -d "$full" ]] || continue
    echo "── $dir ──"
    for sno in "$full"/*.sno; do
        [[ -f "$sno" ]] || continue
        run_test "$sno"
    done
    echo ""
done

echo "============================================"
echo -e "Results: ${GREEN}$PASS passed${RESET}, ${RED}$FAIL failed${RESET}, ${YELLOW}$SKIP skipped${RESET}"
[[ $FAIL -eq 0 ]] && echo -e "${GREEN}ALL PASS${RESET}" && exit 0
exit 1
