#!/usr/bin/env bash
#
# run_klee_pipeline.sh
#
# A robust, reusable pipeline script for symbolic execution of any Coreutils utility.
# It runs a utility through both vanilla KLEE and EVP/VASE-enabled KLEE in sequence,
# creating separate output directories for each run.
#
# Usage:
#   ./run_klee_pipeline.sh <utility> [-- extra app args...]
#
# Description:
#   1. Accepts a utility name (e.g., 'du', 'ls', 'chown').
#   2. Extracts the base LLVM bitcode if it doesn't already exist.
#   3. Runs vanilla KLEE on the bitcode, storing results in 'klee-runs/<utility>/vanilla-<timestamp>'.
#   4. Runs EVP/VASE KLEE on the same bitcode, storing results in 'klee-runs/<utility>/evp-<timestamp>'.
#
# Environment Variables (optional overrides):
#   ROOT:             Base directory of the klee-mm-benchmarks.
#                     (Default: ~/Downloads/klee-mm-benchmarks/coreutils)
#   KLEE_BIN:         Path to the KLEE executable.
#                     (Default: /home/roxana/klee-env/klee-source/klee/build/bin/klee)
#   VASE_MAP:         Path to the VASE limitedValuedMap.json for the utility.
#                     (Default: $ROOT/evp_artifacts/<utility>/limitedValuedMap.json)
#   TEST_ENV:         Path to the shared 'test.env' file for KLEE.
#                     (Default: $ROOT/test.env)
#   KLEE_MAX_TIME:    Maximum wall time for each KLEE run. (Default: 180s)
#   KLEE_MAX_SOLVER_TIME: Maximum time for a single solver query. (Default: 30s)
#

set -euo pipefail

# --- Helper Functions ---
die() { echo "ERROR: $*" >&2; exit 1; }
note() { echo "[INFO] $*"; }
log_run() { echo; echo "====== $1 ======"; }

# --- Argument Parsing ---
PROG="${1:-}"
shift || true
[[ -n "$PROG" ]] || die "Usage: $0 <utility> [-- extra app args...]"

APP_ARGS=()
if [[ "${1:-}" == "--" ]]; then
  shift
  APP_ARGS=("$@")
fi

# --- Configuration and Defaults (override via env) ---
: "${ROOT:=${HOME}/Downloads/klee-mm-benchmarks/coreutils}"
: "${COREUTILS_DIR:=${ROOT}/coreutils-8.31}"
: "${OBJ_SRC:=${COREUTILS_DIR}/obj-llvm/src}"
: "${ARTIFACTS_DIR:=${ROOT}/evp_artifacts/${PROG}}"
: "${VASE_MAP:=${ARTIFACTS_DIR}/limitedValuedMap.json}"
: "${TEST_ENV:=${ROOT}/test.env}"
: "${KLEE_OUT_BASE:=${ROOT}/klee-runs}"
: "${KLEE_BIN:=/home/roxana/klee-env/klee-source/klee/build/bin/klee}"
: "${KLEE_MAX_TIME:=180s}"
: "${KLEE_MAX_SOLVER_TIME:=30s}"
: "${KLEE_MEM_MB:=1000}"

BC_BASE="${ARTIFACTS_DIR}/${PROG}.base.bc"

UTIL_DIR="$ROOT/$PROG"

RUN_ID="${1:-$(date -u +%Y%m%d-%H%M%S)}"

# --- Input Validation ---
ensure_inputs() {
  note "Validating inputs for utility: $PROG"
  command -v "$KLEE_BIN" >/dev/null 2>&1 || die "KLEE executable not found at '$KLEE_BIN'"
  command -v extract-bc >/dev/null 2>&1 || die "'extract-bc' not found in PATH"
  [[ -d "$OBJ_SRC" ]] || die "Coreutils build directory not found at '$OBJ_SRC'"
  [[ -x "${OBJ_SRC}/${PROG}" ]] || die "Coreutils binary not found: '${OBJ_SRC}/${PROG}'"

  mkdir -p "$ARTIFACTS_DIR"

  if [[ ! -f "$BC_BASE" ]]; then
    note "Bitcode not found. Extracting from binary -> $BC_BASE"
    extract-bc -o "$BC_BASE" "${OBJ_SRC}/${PROG}"
  fi
  [[ -f "$BC_BASE" ]] || die "Failed to find or create bitcode: $BC_BASE"

  if [[ ! -f "$VASE_MAP" ]]; then
    note "Warning: VASE map not found at '$VASE_MAP'. EVP run will be skipped."
  fi

  if [[ ! -f "$TEST_ENV" ]]; then
    note "Warning: KLEE environment file not found at '$TEST_ENV'. Runs will proceed without it."
  fi
  note "Input validation complete."
}

# --- KLEE Execution ---
# Shared KLEE flags for both vanilla and EVP runs
KLEE_COMMON_FLAGS=(
  --libc=uclibc
  --posix-runtime
  --simplify-sym-indices
  --write-cvcs
  --write-cov
  --output-module
  --max-memory="$KLEE_MEM_MB"
  --disable-inlining
  --optimize
  --use-forked-solver
  --use-cex-cache
  --external-calls=all
  --only-output-states-covering-new
  ${TEST_ENV:+"--env-file=$TEST_ENV"}
  --max-sym-array-size=4096
  --max-solver-time="$KLEE_MAX_SOLVER_TIME"
  --max-time="$KLEE_MAX_TIME"
  --watchdog
  --max-memory-inhibit=false
  --max-static-fork-pct=1
  --max-static-solve-pct=1
  --max-static-cpfork-pct=1
  --switch-type=internal
  --search=random-path
  --search=nurs:covnew
  --use-batching-search
  --batch-instructions=10000
)

# Symbolic arguments for the utility
KLEE_SYM_ARGS=(
  --sym-args 0 3 10
  --sym-files 1 8
  --sym-stdin 8
  --sym-stdout
)

# Function to run a KLEE instance (vanilla or EVP)
run_klee() {
  local type=$1 # 'vanilla' or 'evp'
  local run_tag=$2
  local out_dir="$UTIL_DIR/klee-${type}-out-$RUN_ID"

  # Create the sandbox directory
  local sandbox
  sandbox=$(mktemp -d "/tmp/${PROG}-${type}-XXXXXX")

  ( # Begin subshell to localize the trap
    trap 'rm -rf "$sandbox"' EXIT
    log_run "Starting KLEE ($type) run for '$PROG'"
    note "Output directory: $out_dir"
    note "Sandbox directory: $sandbox"
    mkdir -p "$UTIL_DIR"   # parent only
    rm -rf "$out_dir"

    local klee_run_flags=()
    if [[ "$type" == "evp" ]]; then
      klee_run_flags+=(--use-vase --vase-map="$VASE_MAP")
    fi

    "$KLEE_BIN" \
      "${klee_run_flags[@]}" \
      "${KLEE_COMMON_FLAGS[@]}" \
      --run-in-dir="$sandbox" \
      --output-dir="$out_dir" \
      "$BC_BASE" \
      "${KLEE_SYM_ARGS[@]}" \
      -- "${APP_ARGS[@]}"

    local ktest_count
    ktest_count=$(find "$out_dir" -type f -name 'test*.ktest' | wc -l)
    note "KLEE ($type) run finished. Found $ktest_count generated tests."
  ) # End subshell and cleanup sandbox on exit
}

# --- Main Execution Logic ---
main() {
  ensure_inputs
  local run_tag
  run_tag=$(date -u +%Y%m%dT%H%M%SZ)

  # 1. Run Vanilla KLEE
  run_klee "vanilla" "$run_tag"

  # 2. Run EVP KLEE (if map exists)
  if [[ -f "$VASE_MAP" ]]; then
    run_klee "evp" "$run_tag"
  else
    log_run "Skipping EVP run because VASE map was not found."
  fi

  note "All runs for '$PROG' (tag: $run_tag) complete."
  note "Check outputs in: ${KLEE_OUT_BASE}/${PROG}/"
}

main
