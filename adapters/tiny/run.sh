#!/usr/bin/env bash
# snobol4harness/adapters/tiny/run.sh
# Run a .sno file through TINY (snobol4x) engine and emit program stdout only.
# Usage: run.sh <file.sno> [< input]
# Calling convention: stdin → program stdin, stdout → program output.
#
# Requires: snobol4x built; TINY_REPO env var or default $HOME/snobol4x.
set -euo pipefail
SNO_FILE="$1"
TINY_REPO="${TINY_REPO:-$HOME/snobol4x}"
TINY_BIN="$TINY_REPO/src/sno2c/sno2c"

if [[ ! -x "$TINY_BIN" ]]; then
    echo "SKIP: sno2c not found at $TINY_BIN" >&2
    exit 2
fi

# sno2c C backend: compile to temp binary, run it
TMPDIR_RUN=$(mktemp -d)
trap 'rm -rf "$TMPDIR_RUN"' EXIT
CFILE="$TMPDIR_RUN/prog.c"
BINARY="$TMPDIR_RUN/prog"

INC="$TINY_REPO/snobol4corpus/programs/inc"
"$TINY_BIN" -I"$INC" "$SNO_FILE" > "$CFILE" 2>/dev/null
gcc -O2 -o "$BINARY" "$CFILE" 2>/dev/null
exec "$BINARY"
