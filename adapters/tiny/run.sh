#!/usr/bin/env bash
# snobol4harness/adapters/tiny/run.sh
# Run a .sno file through TINY (one4all) engine and emit program stdout only.
# Usage: run.sh <file.sno> [< input]
# Calling convention: stdin → program stdin, stdout → program output.
#
# Requires: one4all built; TINY_REPO env var or default $HOME/one4all.
set -euo pipefail
SNO_FILE="$1"
TINY_REPO="${TINY_REPO:-$HOME/one4all}"
TINY_BIN="$TINY_REPO/src/scrip-cc/scrip-cc"

if [[ ! -x "$TINY_BIN" ]]; then
    echo "SKIP: scrip-cc not found at $TINY_BIN" >&2
    exit 2
fi

# scrip-cc C backend: compile to temp binary, run it
TMPDIR_RUN=$(mktemp -d)
trap 'rm -rf "$TMPDIR_RUN"' EXIT
CFILE="$TMPDIR_RUN/prog.c"
BINARY="$TMPDIR_RUN/prog"

INC="$TINY_REPO/snobol4corpus/programs/inc"
"$TINY_BIN" -I"$INC" "$SNO_FILE" > "$CFILE" 2>/dev/null
gcc -O2 -o "$BINARY" "$CFILE" 2>/dev/null
exec "$BINARY"
