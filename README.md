# SNOBOL4-harness

Shared test infrastructure for the SNOBOL4-plus compiler/runtime family.

Serves three compiler/runtime repos:

| Repo | What |
|------|------|
| [SNOBOL4-dotnet](https://github.com/SNOBOL4-plus/SNOBOL4-dotnet) | Full SNOBOL4/SPITBOL → .NET/MSIL |
| [SNOBOL4-jvm](https://github.com/SNOBOL4-plus/SNOBOL4-jvm) | Full SNOBOL4/SPITBOL → JVM bytecode |
| [SNOBOL4-tiny](https://github.com/SNOBOL4-plus/SNOBOL4-tiny) | Native compiler → x86-64 ASM |

## What Goes Here

| Component | Status |
|-----------|--------|
| Oracle build scripts (CSNOBOL4 + SPITBOL from source) | Planned |
| Cross-engine runner — same program on all three engines, diff outputs | Planned |
| Worm generator bridge — feed generated programs to all three engines | Planned |
| Three-oracle triangulation (SPITBOL + CSNOBOL4 → ground truth) | Planned |
| `diff_monitor.py` — Sprint 20 double-trace diff tool | Planned |
| Corpus test runner — all SNOBOL4-corpus programs × all engines | Planned |
| Coverage grid — feature × engine pass/fail matrix | Planned |

## Design Principles

- **Language-agnostic interface.** Each engine exposes `run(program, input) → output`.
  The harness does not care whether the engine is C#, Clojure, or C.
- **Corpus-driven.** Test programs live in
  [SNOBOL4-corpus](https://github.com/SNOBOL4-plus/SNOBOL4-corpus).
  No test programs live here.
- **Oracle-first.** CSNOBOL4 and SPITBOL are always ground truth.
  The harness builds them, runs them, and compares our engines against them.
- **Incremental.** Start with the cross-engine runner. Add components one at a time.

## Status

**Created 2026-03-11. Design phase. No code yet.**

First sprint: migrate `harness.clj` from SNOBOL4-jvm, write thin engine wrappers
(`run_dotnet.sh`, `run_tiny.sh`), write `crosscheck.sh`.

Full design: see `PLAN.md §7` in
[SNOBOL4-plus/.github](https://github.com/SNOBOL4-plus/.github).
