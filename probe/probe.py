#!/usr/bin/env python3
"""
probe.py — Statement-by-statement variable state probe.

Runs a SNOBOL4 program N times with &STLIMIT = 1, 2, ... N.
Each run prepends two lines to the subject source (no modification
to the original file) and captures the &DUMP=2 output at cutoff.
Prints what changed after each statement — a frame-by-frame replay.

Usage:
    probe.py program.sno [--oracle csnobol4|spitbol|both] [--max N] [--var VAR ...]
    echo '...snobol...' | probe.py [--oracle csnobol4|spitbol|both] [--max N]

The two injected lines:
    &STLIMIT = N
    &DUMP = 2
"""

import argparse, subprocess, sys, re, tempfile, os

ORACLES = {
    "csnobol4": ["snobol4", "-f", "-P256k"],
    "spitbol":  ["spitbol", "-b"],
}

NOISE = re.compile(
    r"stmts exec|memory used|memory left|time msec|regen"
    r"|Normal term|execution time|Statement count exceeds|Error 244"
    r"|Limit on statement|Error 22\b|Error \d+ in statement \d+", re.I
)

BUILTIN_PATTERNS = {'ABORT','ARB','BAL','FAIL','FENCE','REM','SUCCEED'}
BORING_KEYWORDS  = {
    '&ABEND','&ANCHOR','&CASE','&CODE','&ERRLIMIT','&FATALLIMIT',
    '&FILL','&FTRACE','&FULLSCAN','&GTRACE','&INPUT','&MAXLNGTH',
    '&OUTPUT','&TRACE','&TRIM',
}

def inject(src, stlimit):
    """Prepend &STLIMIT and &DUMP to source, keep subject END."""
    lines = src.rstrip().splitlines()
    end_idx = None
    for i in range(len(lines) - 1, -1, -1):
        if re.match(r'^\s*END\s*$', lines[i]) or re.match(r'^\w+\s+END\s*$', lines[i].strip()):
            end_idx = i
            break
    subject = "\n".join(lines[:end_idx] if end_idx is not None else lines)
    return f"        &STLIMIT = {stlimit}\n        &DUMP = 2\n" + subject + "\nEND\n"

def run_once(cmd, src, stlimit):
    wrapped = inject(src, stlimit)
    with tempfile.NamedTemporaryFile(mode='w', suffix='.sno', delete=False) as f:
        f.write(wrapped)
        fname = f.name
    try:
        r = subprocess.run(cmd + [fname], capture_output=True, text=True, timeout=15)
        return (r.stdout + r.stderr).replace(fname, '<prog>')
    except subprocess.TimeoutExpired:
        return None
    finally:
        os.unlink(fname)

def parse(raw):
    """Return (prog_output_lines, vars_dict) from one oracle run."""
    lines = raw.splitlines()
    dump_start = None
    for i, line in enumerate(lines):
        if '\x0c' in line or re.match(r'^\s*dump of', line, re.I):
            dump_start = i
            break

    prog_lines = [l.rstrip() for l in (lines[:dump_start] if dump_start else lines)
                  if l.strip() and not NOISE.search(l)]

    vars_ = {}
    if dump_start is not None:
        for line in lines[dump_start:]:
            m = re.match(r'^([A-Za-z&][A-Za-z0-9_]*)\s*=\s*(.*)', line.strip())
            if m:
                vars_[m.group(1).upper()] = m.group(2).strip().strip("'")
    return prog_lines, vars_

def interesting(key, old, new, watch):
    if watch:
        return key.lstrip('&') in watch or key in watch
    if key in BUILTIN_PATTERNS and old is None and new == 'PATTERN':
        return False
    if key in BORING_KEYWORDS and old is None:
        return False
    return True

def probe(src, oracle_key, max_stmts, watch=None):
    cmd    = ORACLES[oracle_key]
    prev   = {}
    frames = []

    for n in range(1, max_stmts + 1):
        raw = run_once(cmd, src, n)
        if raw is None:
            print(f"  stmt {n:3d}: TIMEOUT"); break

        prog_lines, vars_ = parse(raw)

        all_keys = set(vars_) | set(prev)
        changed  = {k: (prev.get(k), vars_.get(k))
                    for k in all_keys if prev.get(k) != vars_.get(k)}
        display  = {k: v for k, v in changed.items()
                    if interesting(k, *v, watch)}

        print(f"\n  ── stmt {n:3d} {'─'*52}")
        for line in prog_lines:
            print(f"     OUT  {line}")
        for k in sorted(display):
            old, new = display[k]
            tag   = "NEW" if old is None else "CHG"
            old_s = repr(old) if old is not None else "<undef>"
            new_s = repr(new) if new is not None else "<undef>"
            print(f"     {tag}  {k:<22s} {old_s:>22s} → {new_s}")
        if not prog_lines and not display:
            print(f"     (no change)")

        frames.append((n, prog_lines, dict(vars_)))
        prev = dict(vars_)

    return frames

def diff(frames_cs, frames_sp):
    skip = {'&STLIMIT','&DUMP','&STCOUNT','&FNCLEVEL','&LASTNO','&STNO',
            '&FILE','&LINE','&LASTFILE','&LASTLINE','&PROFILE',
            '&ERRTEXT','&ERRTYPE','&RTNTYPE'}
    any_diff = False
    for (n, _, va), (_, _, vb) in zip(frames_cs, frames_sp):
        keys = (set(va) | set(vb)) - skip
        diffs = [(k, va.get(k,'<undef>'), vb.get(k,'<undef>'))
                 for k in sorted(keys) if va.get(k) != vb.get(k)]
        if diffs:
            any_diff = True
            print(f"\n  stmt {n:3d}:")
            for k, a, b in diffs:
                print(f"    {k:<22s}  cs={a!r:<28s}  sp={b!r}")
    if not any_diff:
        print("  (no differences)")

def main():
    ap = argparse.ArgumentParser(description=__doc__,
             formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('program', nargs='?', help='.sno file (stdin if omitted)')
    ap.add_argument('--oracle', choices=['csnobol4','spitbol','both'], default='csnobol4')
    ap.add_argument('--max',  type=int, default=20, metavar='N',
                    help='Probe statements 1..N (default 20)')
    ap.add_argument('--var',  nargs='*', metavar='VAR',
                    help='Only show these variables')
    args   = ap.parse_args()
    src    = open(args.program).read() if args.program else sys.stdin.read()
    watch  = set(v.upper().lstrip('&') for v in args.var) if args.var else None
    oracles = ['csnobol4','spitbol'] if args.oracle == 'both' else [args.oracle]

    all_frames = {}
    for key in oracles:
        print(f"\n{'='*72}")
        print(f"  PROBE  {key}  max={args.max}"
              + (f"  watch={sorted(watch)}" if watch else ""))
        print(f"{'='*72}")
        all_frames[key] = probe(src, key, args.max, watch)

    if args.oracle == 'both':
        print(f"\n{'='*72}")
        print(f"  DIFF  csnobol4 vs spitbol")
        print(f"{'='*72}")
        diff(all_frames['csnobol4'], all_frames['spitbol'])

if __name__ == '__main__':
    main()
