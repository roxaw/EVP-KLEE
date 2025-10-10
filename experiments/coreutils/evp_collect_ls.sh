#!/bin/bash

# Script to run coreutils 'ls' utility test cases with EVP instrumentation
# and generate a limited valued map.  It dynamically discovers test
# scripts under tests/ls and runs them with the instrumented ls binary.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Determine the location of the coreutils source tree
COREUTILS_DIR="$SCRIPT_DIR/coreutils-8.31"
if [ ! -d "$COREUTILS_DIR" ]; then
    if [ -d "$SCRIPT_DIR/../coreutils-8.31" ]; then
        COREUTILS_DIR="$SCRIPT_DIR/../coreutils-8.31"
    fi
fi

# Utility-specific paths
UTIL="ls"
UTIL_DIR="$SCRIPT_DIR/evp_artifacts/${UTIL}"
LOG_FILE="$UTIL_DIR/collection.log"

# LLVM and EVP configuration
export OPT=/usr/lib/llvm-10/bin/opt
export PASS_SO=/home/roxana/VASE-klee/vasepass/libVaseInstrumentPass.so
export LOG_C=/home/roxana/VASE-klee/logger.c

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

mkdir -p "$UTIL_DIR"
echo "=== ${UTIL^^} Value Collection Started $(date) ===" > "$LOG_FILE"

# Verify base bitcode and instrument
cd "$UTIL_DIR"
if ! sha256sum -c "${UTIL}.base.bc.sha256" >/dev/null 2>&1; then
    log "Error: Base bitcode verification failed"
    exit 1
fi

log "Applying EVP instrumentation..."
"$OPT" -load "$PASS_SO" -vase-instrument "${UTIL}.base.bc" -o "${UTIL}_instr.bc"

# Build logger and link it with the instrumented bitcode, then produce native exe
log "Compiling logger and linking instrumented ${UTIL}..."
clang -O0 -emit-llvm -c "$LOG_C" -o "$UTIL_DIR/logger.bc"
llvm-link "$UTIL_DIR/${UTIL}_instr.bc" "$UTIL_DIR/logger.bc" -o "$UTIL_DIR/${UTIL}_final.bc"
clang -O2 "$UTIL_DIR/${UTIL}_final.bc" -o "$UTIL_DIR/${UTIL}_final_exe" -lcap -lselinux || true

# Prepare VASE log
export VASE_LOG="$UTIL_DIR/vase_value_log.txt"
rm -f "$VASE_LOG"
log "Set VASE_LOG to: $VASE_LOG"

# Enter coreutils tree; adjust permissions if necessary
if ! cd "$COREUTILS_DIR" 2>/dev/null; then
    log "Cannot access $COREUTILS_DIR, fixing permissions"
    chmod -R u+rwX "$COREUTILS_DIR" || true
    cd "$COREUTILS_DIR" || { log "Error: Cannot access $COREUTILS_DIR"; exit 1; }
fi

# Source test environment
set -a
source "$SCRIPT_DIR/testing-env.sh"
set +a

log "Building native instrumented ${UTIL} and installing symlink into ./src..."

WRAPPER_PATH="$COREUTILS_DIR/src/${UTIL}"
ORIG_PATH="${WRAPPER_PATH}.orig"
if [ -x "$WRAPPER_PATH" ] && [ ! -e "$ORIG_PATH" ]; then
  mv -f "$WRAPPER_PATH" "$ORIG_PATH"
fi
if [ -x "$UTIL_DIR/${UTIL}_final_exe" ]; then
  ln -sfn "$UTIL_DIR/${UTIL}_final_exe" "$WRAPPER_PATH"
else
  cat > "$WRAPPER_PATH" <<'WRAP'
#!/bin/sh
export VASE_LOG="__UTIL_DIR__/vase_value_log.txt"
exec /usr/lib/llvm-10/bin/lli "__UTIL_DIR__/__UTIL___final.bc" "$@"
WRAP
  chmod +x "$WRAPPER_PATH"
  sed -i "s#__UTIL_DIR__#${UTIL_DIR//\/\\/}#g; s#__UTIL__#${UTIL}#g" "$WRAPPER_PATH"
fi

log "Running ${UTIL} test cases..."

# Collect tests for the utility
TESTS=()
if [ -d tests/${UTIL} ]; then
    while IFS= read -r -d '' t; do
        TESTS+=("$t")
    done < <(find tests/${UTIL} -maxdepth 1 -type f \( -name '*.sh' -o -perm -u+x \) -print0 | sort -z)
fi

# Fallback to known tests for ls if none found
if [ ${#TESTS[@]} -eq 0 ]; then
    # Add some common ls tests; adjust as needed
    TESTS+=(
        "tests/ls/basic.sh"
        "tests/ls/no-arg.sh"
    )
fi

# Remove duplicates and non-existing files
unique_tests=()
for t in "${TESTS[@]}"; do
    if [ -f "$t" ] && [[ ! " ${unique_tests[*]} " =~ " $t " ]]; then
        unique_tests+=("$t")
    fi
done

if [ ${#unique_tests[@]} -eq 0 ]; then
    log "No ${UTIL} tests found. Skipping value collection."
    exit 0
fi

for t in "${unique_tests[@]}"; do
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
    if built_programs=" ${UTIL} " srcdir="$SRC" VERBOSE=yes "$t" >"$UTIL_DIR/$base_name.out" 2>"$UTIL_DIR/$base_name.err"; then
        log "PASS: $t"
    else
        st=$?
        if [ $st -eq 77 ] || [ $st -eq 127 ]; then
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
    log "No value log generated after running ${UTIL} tests"
fi

log "Restoring original ${UTIL} binary (if saved)"
if [ -e "$ORIG_PATH" ]; then
  mv -f "$WRAPPER_PATH" "$WRAPPER_PATH.instr-wrapper" 2>/dev/null || true
  mv -f "$ORIG_PATH" "$WRAPPER_PATH"
fi

log "Value collection completed for ${UTIL}"
echo "=== ${UTIL^^} Value Collection Completed $(date) ===" >> "$LOG_FILE"

cd "$SCRIPT_DIR"

python3 generate_limited_map.py \
  --log evp_artifacts/${UTIL}/vase_value_log.txt \
  --out evp_artifacts/${UTIL}/limitedValuedMap.json \
  --max-values 3 \
  --min-occurrence 5

log "Map generation completed"
echo "=== Map Generation Completed $(date) ===" >> "$LOG_FILE"
