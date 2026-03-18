# CSNOBOL4 2.3.3 — Oracle Build

Source: `snobol4-2_3_3_tar.gz` (upload to `/mnt/user-data/uploads/`)

## Build

```bash
apt-get install -y build-essential libgmp-dev m4
mkdir -p /home/socrates/csnobol4-src
tar xzf /mnt/user-data/uploads/snobol4-2_3_3_tar.gz \
    -C /home/socrates/csnobol4-src/ --strip-components=1
cd /home/socrates/csnobol4-src

# Apply STNO trace patch (required — see below)
sed -i '/if (!chk_break(0))/{N;/goto L_INIT1;/d}' \
    snobol4.c isnobol4.c

./configure --prefix=/usr/local
make -j4
make install
# Binary: /usr/local/bin/snobol4
```

## Invocation

```bash
snobol4 -f -P256k program.sno
```

- `-f`     fold identifiers to uppercase (required — DATA/DEFINE case)
- `-P256k` pattern stack size

## STNO Trace Patch

Without this patch, `TRACE('STNO','KEYWORD')` silently accepts but never fires.

**Root cause**: PLB113 edit in `isnobol4.c` gated the `&STNO` KEYWORD trace on
`chk_break(0)`, which only returns nonzero after `BREAKPOINT(stmtno,1)` is called.
The v311.sil spec requires no such gate.

**Fix**: delete 2 lines in each of `snobol4.c` and `isnobol4.c`:
```
if (!chk_break(0))
    goto L_INIT1;
```
These appear immediately before `if (!LOCAPT(ATPTR,TKEYL,STNOKY))`.

The sed command above handles both files in one pass.

## &DUMP=2 Format

```
^LDump of variables at termination

Natural variables

NAME = VALUE
...

Unprotected keywords

&NAME = VALUE
...
```

Starts with form-feed (`\x0c`). Names uppercase. Used by `probe/probe.py`.
