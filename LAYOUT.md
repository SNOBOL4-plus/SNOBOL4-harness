# SNOBOL4-harness Layout

```
SNOBOL4-harness/
│
├── probe/                      # Probe testing — &STLIMIT + &DUMP frame-by-frame replay
│   ├── probe.py                # Shell tool: run any .sno N times at &STLIMIT=1..N
│   │                           #   --oracle csnobol4|spitbol|both  --max N  --var VAR
│   ├── test_helpers.clj        # JVM: run-to-step, probe-at, bisect-divergence,
│   │                           #      probe-test macro, run-with-restart (Sprint 18C)
│   └── test_probe18c.clj       # JVM: Sprint 18C probe tests (step-limit, bisect, restart)
│
├── monitor/                    # Monitor testing — TRACE() on variables, functions, labels
│   ├── trace.clj               # JVM: TRACE/STOPTR implementation, *trace-output* binding
│   └── test_trace.clj          # JVM: &STLIMIT/&STCOUNT tests + full TRACE type coverage
│
├── oracles/                    # Oracle build scripts and wrappers
│   ├── csnobol4/               # CSNOBOL4 2.3.3 — build instructions, STNO patch
│   └── spitbol/                # SPITBOL x64 — build instructions, systm.c patch
│
├── adapters/                   # Per-engine calling conventions (TBD — design open)
│   ├── jvm/
│   │   ├── harness.clj         # JVM cross-engine runner + step-probe oracle runners
│   │   │                       #   run-csnobol4-to-step, run-spitbol-to-step,
│   │   │                       #   run-clojure-to-step, three-oracle triangulation
│   │   └── generator.clj       # Worm generator — feeds programs to all three engines
│   ├── dotnet/                 # (placeholder — crosscheck.sh TBD)
│   └── tiny/
│       ├── oracle_sprint14.py  # Sprint 14 parser oracle
│       ├── oracle_sprint15.py  # Sprint 15 expression oracle
│       ├── oracle_sprint16.py  # Sprint 16 build oracle
│       ├── oracle_sprint18.py  # Sprint 18 evaluator oracle
│       ├── oracle_sprint19.py  # Sprint 19 oracle
│       └── oracle_sprint20_parser.py  # Sprint 20 parser oracle
│
├── crosscheck/                 # Cross-engine diff runner (TBD)
│   └── (crosscheck.sh — run one .sno on all engines, diff outputs)
│
└── doc/
    └── (design notes TBD)
```

## What lives here vs in each repo

**Lives here (harness):**
- All oracle-facing tools: probe.py, crosscheck.sh, diff_monitor.py
- The JVM harness/generator (migrated from SNOBOL4-jvm)
- Probe and monitor test infrastructure (migrated from SNOBOL4-jvm)
- Sprint oracle scripts (migrated from SNOBOL4-tiny)
- Oracle build scripts and patches

**Stays in each repo:**
- Engine implementation (compiler, runtime)
- Engine-specific unit tests that test internals (lexer, parser, codegen)
- Engine-specific test fixtures

**Calling convention (open question):**
Each engine needs to expose a standard `run(program, input) → output` interface
that harness crosscheck.sh can call. Current candidates:
- `dotnet run` / `lein run` / `./beautiful`
- A thin shell wrapper in each repo: `engines/run.sh`
- stdin/stdout only — no engine-specific flags
