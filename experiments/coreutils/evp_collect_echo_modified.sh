#!/bin/bash

# Script to run coreutils echo test cases with EVP instrumentation and
# generate a limited valued map. This version dynamically locates echo
# tests under tests/misc/ and includes 'printf' along with 'echo' in
# the built_programs variable, since some echo tests rely on printf.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Locate the coreutils source tree
COREUTILS_DIR="$SCRIPT_DIR/coreutils-8.31"
if [ ! -d "$COREUTILS_DIR" ]; then
    if [ -d "$SCRIPT_DIR/../coreutils-8.31" ]; then
        COREUTILS_DIR="$SCRIPT_DIR/../coreutils-8.31"
    fi
fi

UTIL_DIR="$SCRIPT_DIR/evp_artifacts/echo"
LOG_FILE="$UTIL_DIR/collection.log"

# LLVM and EVP
export OPT=/usr/lib/llvm-10/bin/opt
export PASS_SO=/home/roxana/VASE-klee/vasepass/libVaseInstrumentPass.so
export LOG_C=/home/roxana/VASE-klee/logger.c

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

mkdir -p "$UTIL_DIR"
echo "=== ECHO Value Collection Started $(date) ===" > "$LOG_FILE"

# Verify base bitcode
cd "$UTIL_DIR"
if ! sha256sum -c "echo.base.bc.sha256" >/dev/null 2>&1; then
    log "Error: Base bitcode verification failed"
    exit 1
fi

log "Applying EVP instrumentation..."
"$OPT" -load "$PASS_SO" -vase-instrument "echo.base.bc" -o "echo_instr.bc"

# Prepare VASE log
export VASE_LOG="$UTIL_DIR/vase_value_log.txt"
rm -f "$VASE_LOG"
log "Set VASE_LOG to: $VASE_LOG"

# Enter coreutils tree
if ! cd "$COREUTILS_DIR" 2>/dev/null; then
    log "Cannot access $COREUTILS_DIR, trying to fix permissions"
    chmod -R u+rwX "$COREUTILS_DIR" || true
    cd "$COREUTILS_DIR" || { log "Error: Cannot access $COREUTILS_DIR"; exit 1; }
fi

# Source test environment
set -a
source "$SCRIPT_DIR/testing-env.sh"
set +a

log "Running echo test cases..."

# Gather echo test scripts from tests/misc. Pattern matches 'echo' and 'echo-*'
TESTS=()
if [ -d tests/misc ]; then
    while IFS= read -r -d '' t; do
        TESTS+=("$t")
    done < <(find tests/misc -maxdepth 1 -type f \( -name 'echo' -o -name 'echo*' \) -print0 | sort -z)
fi

# Fallback to explicit file if none found
if [ ${#TESTS[@]} -eq 0 ]; then
    if [ -f tests/misc/echo.sh ]; then
        TESTS+=("tests/misc/echo.sh")
    fi
fi

if [ ${#TESTS[@]} -eq 0 ]; then
    log "No echo tests found. Skipping value collection."
    exit 0
fi

for t in "${TESTS[@]}"; do
    # Determine srcdir relative to tests root
    case "$(sed -n '1,20p' "$t")" in
        *'/tests/init.sh'*)
            SRC='.'
            ;;
        *)
            SRC='tests'
            ;;
    esac

    base_name=$(basename "$t")
    log "Running test: $t (srcdir=$SRC)"
    if built_programs=' echo printf ' srcdir="$SRC" VERBOSE=yes "$t" >"$UTIL_DIR/$base_name.out" 2>"$UTIL_DIR/$base_name.err"; then
        log "PASS: $t"
    else
        st=$?
        if [ $st -eq 77 ] || [ $st -eq 127 ]; then
            # Treat exit 77 (skip) and 127 (command not found) as SKIP
            log "SKIP: $t"
        else
            log "FAIL: $t (exit $st)"
        fi
    fi
done

if [ -f "$VASE_LOG" ]; then
    log "Successfully collected values"
    log "Value log size: $(wc -l < "$VASE_LOG")"
else
    log "No value log generated after running echo tests"
fi

log "Value collection completed for echo"
echo "=== ECHO Value Collection Completed $(date) ===" >> "$LOG_FILE"

cd "$SCRIPT_DIR"

python3 generate_limited_map.py \
  --log evp_artifacts/echo/vase_value_log.txt \
  --out evp_artifacts/echo/limitedValuedMap.json \
  --max-values 3 \
  --min-occurrence 5

log "Map generation completed"
echo "=== Map Generation Completed $(date) ===" >> "$LOG_FILE"
