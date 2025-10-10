#!/bin/bash

# Script to run test cases for a specified coreutils utility wi# Run specific test cases for the utility
log "Running ${PROG} test cases..."

# Exit on any error
set -e

# Usage: ./evp_collect_du_modified.sh <utility>
PROG=${1:-}
if [[ -z "${PROG}" ]]; then
  echo "Usage: $0 <utility>" >&2
  exit 1
fi

# Directory setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Attempt to locate the coreutils source directory.  By default it
# assumes coreutils-8.31 lives alongside this script in the same
# directory.  If that directory doesn't exist, it falls back one
# level up.  This helps avoid paths like coreutils/coreutils-8.31.
COREUTILS_DIR="$SCRIPT_DIR/coreutils-8.31"
if [ ! -d "$COREUTILS_DIR" ]; then
    if [ -d "$SCRIPT_DIR/../coreutils-8.31" ]; then
        COREUTILS_DIR="$SCRIPT_DIR/../coreutils-8.31"
    fi
fi

UTIL_DIR="$SCRIPT_DIR/evp_artifacts/${PROG}"
LOG_FILE="$UTIL_DIR/collection.log"

# LLVM and EVP setup
export CLANG=/usr/lib/llvm-10/bin/clang
export OPT=/usr/lib/llvm-10/bin/opt
export LLVMLINK=/usr/lib/llvm-10/bin/llvm-link
export PASS_SO=/home/roxana/VASE-klee/vasepass/libVaseInstrumentPass.so
export LOG_C=/home/roxana/VASE-klee/logger.c

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Initialize log
echo "=== ${PROG^^} Value Collection Started $(date) ===" > "$LOG_FILE"

# Verify base bitcode exists and checksum
cd "$UTIL_DIR"
if ! sha256sum -c "${PROG}.base.bc.sha256" >/dev/null 2>&1; then
    log "Error: Base bitcode verification failed"
    exit 1
fi

# Apply EVP instrumentation
log "Applying EVP instrumentation..."
"$OPT" -load "$PASS_SO" -vase-instrument \
    "${PROG}.base.bc" -o "${PROG}_instr.bc"

# Link instrumented bitcode + logger
log "Linking instrumented bitcode with logger..."
"$CLANG" -O0 -emit-llvm -c "$LOG_C" -o "logger.bc"
"$LLVMLINK" "${PROG}_instr.bc" "logger.bc" -o "${PROG}_final.bc"

# Build final executable
log "Building final instrumented executable..."
EXTRA="$(pkg-config --libs --silence-errors libacl libattr || true)"
"$CLANG" "${PROG}_final.bc" -o "${PROG}_final_exe" -ldl -lpthread -lselinux -lcap ${EXTRA:-}

# Swap the binary in-place
log "Swapping binary to instrumented version..."
cd "$COREUTILS_DIR/obj-llvm/src"
if [[ -f "${PROG}" && ! -f "${PROG}.orig" ]]; then
  cp -a "${PROG}" "${PROG}.orig"
fi
rm -f "${PROG}"
ln -sfn "$(pwd)/${PROG}_final_exe" "./${PROG}"
cd "$UTIL_DIR"

# Set up value collection
export VASE_LOG="$UTIL_DIR/vase_value_log.txt"
rm -f "$VASE_LOG"  # Start fresh
: > "$VASE_LOG"  # Ensure file exists
log "Set VASE_LOG to: $VASE_LOG"

# Change into the coreutils directory, fixing permissions if necessary.
if ! cd "$COREUTILS_DIR" 2>/dev/null; then
    log "Cannot access $COREUTILS_DIR, attempting to add read/execute permissions"
    chmod -R u+rwX "$COREUTILS_DIR" || true
    cd "$COREUTILS_DIR" || { log "Error: Cannot access $COREUTILS_DIR after permission attempt"; exit 1; }
fi

# Set up environment for tests
set -a
source "$SCRIPT_DIR/testing-env.sh"
set +a

export VASE_LOG="/home/roxana/Downloads/klee-mm-benchmarks/coreutils/evp_artifacts/$PROG/vase_value_log.txt"

# Run test cases for the specified utility
log "Running ${PROG} test cases..."

TEST_DIR="tests/${PROG}"
TESTS=()

if [[ -d "$TEST_DIR" ]]; then
  # Use printf to avoid globbing failure when no matches.
  while IFS= read -r -d '' testfile; do
    # Strip leading ./ if present.
    testfile_rel=${testfile#./}
    TESTS+=("$testfile_rel")
  done < <(find "$TEST_DIR" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)
else
  log "Warning: no test directory found for $PROG (expected $TEST_DIR)"
fi

if [[ ${#TESTS[@]} -eq 0 ]]; then
  log "Error: no test scripts found for $PROG.  Skipping test execution."
  exit 1
fi

for t in "${TESTS[@]}"; do
    # Determine srcdir based on whether the test sources tests/init.sh.
    SRC='tests'
    if sed -n '1,20p' "$t" | grep -q '/tests/init.sh'; then
        SRC='.'
    fi
    test_name="$(basename "$t")"
    log "Running test: $t (srcdir=$SRC)"
    if built_programs=" ${PROG} " srcdir="$SRC" VERBOSE=yes "$t" >"$OUT_DIR/${test_name}.out" 2>"$OUT_DIR/${test_name}.err"; then
        log "PASS: $t"
    else
        st=$?
        if [[ $st -eq 77 ]]; then
            log "SKIP: $t"
        else
            log "FAIL: $t (exit $st)"
        fi
    fi
done

# Verify value collection
if [ -f "$VASE_LOG" ]; then
    log "Successfully collected values"
    log "Value log size: $(wc -l < "$VASE_LOG")"
else
    log "Error: No value log generated"
    exit 1
fi

log "Value collection completed for ${PROG}"
echo "=== ${PROG^^} Value Collection Completed $(date) ===" >> "$LOG_FILE"

# Change back to the script's directory before running python
cd "$SCRIPT_DIR"

# Step 2 (map generation)
python3 generate_limited_map.py --log "evp_artifacts/${PROG}/vase_value_log.txt" --out "evp_artifacts/${PROG}/limitedValuedMap.json" --max-values 3 --min-occurrence 5


log "Map generation completed"
echo "=== Map Generation Completed $(date) ===" >> "$LOG_FILE"

