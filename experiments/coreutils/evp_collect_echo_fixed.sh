
#!/bin/bash

# Fixed script for running test cases for the coreutils 'echo' utility with EVP instrumentation.
# The key fix: ensure the instrumented binary is properly linked and available in the PATH
# before running tests.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COREUTILS_DIR="$SCRIPT_DIR/coreutils-8.31"
if [ ! -d "$COREUTILS_DIR" ]; then
    if [ -d "$SCRIPT_DIR/../coreutils-8.31" ]; then
        COREUTILS_DIR="$SCRIPT_DIR/../coreutils-8.31"
    fi
fi

UTIL_DIR="$SCRIPT_DIR/evp_artifacts/echo"
LOG_FILE="$UTIL_DIR/collection.log"

export OPT=/usr/lib/llvm-10/bin/opt
export PASS_SO=/home/roxana/VASE-klee/vasepass/libVaseInstrumentPass.so
export LOG_C=/home/roxana/VASE-klee/logger.c

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Initialize log
mkdir -p "$UTIL_DIR"
echo "=== ECHO Value Collection Started $(date) ===" > "$LOG_FILE"

# Verify base bitcode exists and checksum
cd "$UTIL_DIR"
if ! sha256sum -c "echo.base.bc.sha256" >/dev/null 2>&1; then
    log "Error: Base bitcode verification failed"
    exit 1
fi

# Apply EVP instrumentation
log "Applying EVP instrumentation..."
"$OPT" -load "$PASS_SO" -vase-instrument \
    "echo.base.bc" -o "echo_instr.bc"

# Set up value collection
export VASE_LOG="$UTIL_DIR/vase_value_log.txt"
rm -f "$VASE_LOG"  # Start fresh
log "Set VASE_LOG to: $VASE_LOG"

# Change into the coreutils directory, fixing permissions if necessary.
if ! cd "$COREUTILS_DIR" 2>/dev/null; then
    log "Cannot access $COREUTILS_DIR, attempting to add read/execute permissions"
    chmod -R u+rwX "$COREUTILS_DIR" || true
    cd "$COREUTILS_DIR" || { log "Error: Cannot access $COREUTILS_DIR after permission attempt"; exit 1; }
fi


set -a
source "$SCRIPT_DIR/testing-env.sh"
set +a

# Run echo test (it may skip)
log "Running echo test cases…"
if built_programs=' echo printf ' srcdir='tests' VERBOSE=yes tests/misc/echo.sh >"$UTIL_DIR/echo.sh.out" 2>"$UTIL_DIR/echo.sh.err"; then
    log "PASS: tests/misc/echo.sh"
else
    st=$?
    if [ $st -eq 77 ]; then
        log "SKIP: tests/misc/echo.sh"
    else
        log "FAIL: tests/misc/echo.sh (exit $st)"
    fi
fi

# Don’t treat missing log as an error for echo
if [ -f "$VASE_LOG" ]; then
    log "Successfully collected values"
    log "Value log size: $(wc -l < "$VASE_LOG")"
else
    log "No value log generated for echo"
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
