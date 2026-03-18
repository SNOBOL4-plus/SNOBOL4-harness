# SPITBOL x64 — Oracle Build

Source: `x64-main.zip` (upload to `/mnt/user-data/uploads/`)

## Build

```bash
apt-get install -y build-essential nasm
unzip -q /mnt/user-data/uploads/x64-main.zip -d /home/socrates/spitbol-src/

# Apply systm.c patch (nanoseconds → milliseconds)
cat > /home/socrates/spitbol-src/x64-main/osint/systm.c << 'PATCH'
#include "port.h"
#include "time.h"
int zystm() {
    struct timespec tim;
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &tim);
    long etime = (long)(tim.tv_sec * 1000) + (long)(tim.tv_nsec / 1000000);
    SET_IA(etime);
    return NORMAL_RETURN;
}
PATCH

cd /home/socrates/spitbol-src/x64-main
make
cp sbl /usr/local/bin/spitbol
# Binary: /usr/local/bin/spitbol
```

## Invocation

```bash
spitbol -b program.sno
```

- `-b` suppress banner (required for clean stdout)

## Key Differences from CSNOBOL4

| Feature | CSNOBOL4 | SPITBOL x64 |
|---------|----------|-------------|
| `&STNO` | ✅ | ❌ — use `&LASTNO` |
| `TRACE('STNO','KEYWORD')` | ✅ (patched) | ❌ error 198 |
| `LOAD()` | ✅ dlopen | ❌ EXTFUN=0 |
| `LABELCODE()` | ✅ | ❌ undefined |
| `DATA()` name case | uppercase | lowercase |
| KEYWORD trace targets | STNO, STCOUNT, ... | ERRTYPE, FNCLEVEL, STCOUNT only |

## &DUMP=2 Format

```
dump of natural variables

name = value
...

dump of keyword values

&name = value
...
```

No form-feed. Names lowercase. Normalize to uppercase when comparing with CSNOBOL4.
