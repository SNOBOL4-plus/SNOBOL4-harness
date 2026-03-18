#!/usr/bin/env bash
# bench.sh — run snobol4corpus benchmarks against one or more engines
#
# Usage: bench.sh [--engine ENGINE[,ENGINE...]] [--corpus DIR] [--reps N]
#
# Each engine adapter lives in adapters/<engine>/run.sh
# Calling convention: run.sh <file.sno> [< input] → stdout = program output
#
# Output: wall-clock timing table per engine × benchmark.
# Exit: 0 always (benchmark failures are reported, not fatal).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CORPUS="${CORPUS:-$HOME/snobol4corpus}"
REPS="${REPS:-5}"
ENGINES=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --engine)  ENGINES="$2"; shift 2 ;;
        --corpus)  CORPUS="$2";  shift 2 ;;
        --reps)    REPS="$2";    shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

if [[ -z "$ENGINES" ]]; then
    ENGINES=$(ls "$HARNESS_ROOT/adapters/" 2>/dev/null | tr '\n' ',')
    ENGINES="${ENGINES%,}"
fi

BENCH_DIR="$CORPUS/benchmarks"
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; RESET='\033[0m'

run_engine_bench() {
    local engine="$1"
    local adapter="$HARNESS_ROOT/adapters/$engine/run.sh"

    if [[ ! -x "$adapter" ]]; then
        echo -e "${YELLOW}SKIP engine $engine${RESET} — $adapter not executable"
        return
    fi

    echo -e "${CYAN}=== Engine: $engine ===${RESET}"
    printf "%-30s %8s %8s %8s\n" "Benchmark" "Mean(ms)" "Min(ms)" "Max(ms)"
    printf "%-30s %8s %8s %8s\n" "----------" "--------" "-------" "-------"

    for sno in "$BENCH_DIR"/*.sno; do
        [[ -f "$sno" ]] || continue
        local name
        name=$(basename "$sno" .sno)
        local input="${sno%.sno}.input"

        local times=()
        local i
        for ((i=0; i<REPS; i++)); do
            local t0 t1 elapsed
            t0=$(date +%s%N)
            if [[ -f "$input" ]]; then
                timeout 30 "$adapter" "$sno" < "$input" >/dev/null 2>/dev/null || true
            else
                timeout 30 "$adapter" "$sno" >/dev/null 2>/dev/null || true
            fi
            t1=$(date +%s%N)
            elapsed=$(( (t1 - t0) / 1000000 ))
            times+=("$elapsed")
        done

        # compute mean, min, max
        local sum=0 min=${times[0]} max=${times[0]}
        for t in "${times[@]}"; do
            sum=$((sum + t))
            [[ $t -lt $min ]] && min=$t
            [[ $t -gt $max ]] && max=$t
        done
        local mean=$(( sum / REPS ))

        printf "%-30s %8d %8d %8d\n" "$name" "$mean" "$min" "$max"
    done
    echo ""
}

echo "=== snobol4ever Benchmark Grid ==="
echo "corpus: $BENCH_DIR"
echo "reps:   $REPS"
echo ""

IFS=',' read -ra ENGINE_LIST <<< "$ENGINES"
for engine in "${ENGINE_LIST[@]}"; do
    [[ -n "$engine" ]] && run_engine_bench "$engine"
done
