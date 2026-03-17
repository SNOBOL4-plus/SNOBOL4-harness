# snobol4harness

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Shared test infrastructure for the snobol4ever compiler/runtime family.

Serves three compiler/runtime repos:

| Repo | What |
|------|------|
| [snobol4dotnet](https://github.com/snobol4ever/snobol4dotnet) | Full SNOBOL4/SPITBOL → .NET/MSIL |
| [snobol4jvm](https://github.com/snobol4ever/snobol4jvm) | Full SNOBOL4/SPITBOL → JVM bytecode |
| [snobol4x](https://github.com/snobol4ever/snobol4x) | Native compiler → x86-64 ASM |

## What Goes Here

| Component | Status |
|-----------|--------|
| Oracle build scripts (CSNOBOL4 + SPITBOL from source) | Planned |
| Cross-engine runner — same program on all three engines, diff outputs | Planned |
| Worm generator bridge — feed generated programs to all three engines | Planned |
| Three-oracle triangulation (SPITBOL + CSNOBOL4 → ground truth) | Planned |
| `diff_monitor.py` — Sprint 20 double-trace diff tool | Planned |
| Corpus test runner — all snobol4corpus programs × all engines | Planned |
| Coverage grid — feature × engine pass/fail matrix | Planned |

## Design Principles

- **Language-agnostic interface.** Each engine exposes `run(program, input) → output`.
  The harness does not care whether the engine is C#, Clojure, or C.
- **Corpus-driven.** Test programs live in
  [snobol4corpus](https://github.com/snobol4ever/snobol4corpus).
  No test programs live here.
- **Oracle-first.** CSNOBOL4 and SPITBOL are always ground truth.
  The harness builds them, runs them, and compares our engines against them.
- **Incremental.** Start with the cross-engine runner. Add components one at a time.

## Status

**Created 2026-03-11. Design phase. No code yet.**

First sprint: migrate `harness.clj` from snobol4jvm, write thin engine wrappers
(`run_dotnet.sh`, `run_tiny.sh`), write `crosscheck.sh`.

Full design: see `PLAN.md §7` in
[snobol4ever/.github](https://github.com/snobol4ever/.github).
