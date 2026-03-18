#!/usr/bin/env bash
# snobol4harness/adapters/dotnet/run.sh
# Run a .sno file through DOTNET engine and emit program stdout only.
# Usage: run.sh <file.sno> [< input]
# Calling convention: stdin → program stdin, stdout → program output (no banner).
#
# DOTNET quirk: program output goes to stderr; CWD line goes to stdout.
# -b suppresses sign-on banner. We swap: emit stderr (program output), discard stdout (CWD).
set -euo pipefail
SNO_FILE="$1"
DOTNET_REPO="${DOTNET_REPO:-$HOME/snobol4dotnet}"
DOTNET_ROOT="${DOTNET_ROOT:-/usr/local/dotnet}"
export DOTNET_ROOT
export PATH="$PATH:$DOTNET_ROOT"
SNO4_DLL="$DOTNET_REPO/Snobol4/bin/Release/net10.0/Snobol4.dll"
# Swap stdout/stderr: program output is on fd2, CWD noise on fd1
dotnet "$SNO4_DLL" -b "$SNO_FILE" 2>&1 1>/dev/null
