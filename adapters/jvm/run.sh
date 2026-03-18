#!/usr/bin/env bash
# snobol4harness/adapters/jvm/run.sh
# Run a .sno file through JVM (snobol4jvm) engine and emit program stdout only.
# Usage: run.sh <file.sno> [< input]
# Calling convention: stdin → program stdin, stdout → program output.
#
# Requires: snobol4jvm built; JVM_REPO env var or default $HOME/snobol4jvm.
set -euo pipefail
SNO_FILE="$1"
JVM_REPO="${JVM_REPO:-$HOME/snobol4jvm}"

# Try uberjar first (faster), then lein run
UBERJAR=$(ls "$JVM_REPO"/target/snobol4*.jar 2>/dev/null | head -1 || true)

if [[ -n "$UBERJAR" ]]; then
    exec java -jar "$UBERJAR" "$SNO_FILE"
elif command -v lein >/dev/null 2>&1 && [[ -f "$JVM_REPO/project.clj" ]]; then
    exec lein -o run -m snobol4.main "$SNO_FILE"
else
    echo "SKIP: snobol4jvm not found at $JVM_REPO (no uberjar, no lein)" >&2
    exit 2
fi
