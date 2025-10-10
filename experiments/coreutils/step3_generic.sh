#!/usr/bin/env bash
# step3_generic.sh — Generic Step‑3 driver of the EVP symbolic‑execution pipeline
#
# Runs both vanilla KLEE and EVP/VASE‑enabled KLEE on <utility>.base.bc.
# The script is utility‑agnostic: point it at any Coreutils program that has
# already been bitcode‑instrumented (…/<utility>.base.bc) and has an EVP map
# (…/limitedValuedMap.json).
#
# ──────────────── Usage ──────────────────────────────────────────────────
#   step3_generic.sh <utility> [run‑id] [-- <utility‑runtime‑args>]
#
#     <utility>      Name of the Coreutils program to analyse (e.g. du, ls).
#     [run‑id]       Optional string used to namespace result folders/logs.
#                    Defaults to a UTC timestamp so multiple runs never clash.
#     --             Everything to the right of "--" is forwarded verbatim to
#                    the program inside KLEE (after the symbolic‑input flags).
#
#  Environment variables (all optional)
#  ────────────────────────────────────
#     KLEE_BIN           Absolute path to the klee binary.
#                        ↳ default: "$HOME/klee-env/klee-source/klee/build/bin/klee"
#     EVP_ROOT           Root folder that contains one subdir per utility with:
#                          • <utility>.base.bc
#                          • limitedValuedMap.json
#                          • test.env (if utility needs one)
#                        ↳ default: "$SCRIPT_DIR/evp_artifacts"
#     SANDBOX_DIR        Temporary runtime sandbox. Automatically wiped/created.
#                        ↳ default: /tmp/evp-sandbox
#     EXTRA_KLEE_FLAGS   Additional flags appended *after* the built‑in set.
#     ENV_FILE           Override env‑file supplied to --env-file (POSIX runtime).
#
#  Example
#  ───────
#     ./step3_generic.sh du mytest -- -x  
#     # runs the "du" bitcode with run‑id "mytest" and passes "-x" to du

set -euo pipefail

##############################################################################
# Helper utilities                                                            
##############################################################################
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
KLEE_BIN="${KLEE_BIN:-$HOME/klee-env/klee-source/klee/build/bin/klee}"
EVP_ROOT="${EVP_ROOT:-$SCRIPT_DIR/evp_artifacts}"
SANDBOX_DIR="${SANDBOX_DIR:-/tmp/evp-sandbox}"

die() {
  echo "ERROR: $*" >&2; exit 1;
}

PROG="${1:-}"; 
ARG2="${2:-}"
shift || true
[[ -n "$PROG" ]] || die "Usage: $0 <utility> [-- extra app args]"

die() {
  echo "ERROR: $*" >&2; exit 1;
}

UTIL_DIR="$EVP_ROOT/$PROG"

RUN_ID="${ARG2:-$(date -u +%Y%m%d-%H%M%S)}"

usage() {
  sed -n '1,/^$/p' "$0" | tail -n +2
}

log() {
  printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

fail() {
  log "ERROR: $*"; exit 1;
}

##############################################################################
# Argument parsing                                                            
##############################################################################
# Default extra program arguments (empty by default)
EXTRA_PROG_ARGS=()

##############################################################################
# Path construction                                                           
##############################################################################
BITCODE="$UTIL_DIR/$PROG.base.bc"
MAP_FILE="$UTIL_DIR/limitedValuedMap.json"
LOG_DIR="$UTIL_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/klee_runs_$RUN_ID.log"
TEST_ENV="$SCRIPT_DIR/test.env"
##############################################################################
# Input validation                                                            
##############################################################################
[[ -x "$KLEE_BIN"        ]] || fail "KLEE binary not found: $KLEE_BIN"
[[ -f "$BITCODE"         ]] || fail "Bitcode not found at $BITCODE"
[[ -f "$MAP_FILE"        ]] || fail "VASE map not found at $MAP_FILE"
[[ -f "$TEST_ENV"       ]] || log "Warning: TEST_ENV $TEST_ENV not found; continuing without it."

[[ -f "$BITCODE.sha256" ]] || fail "Checksum file missing: $BITCODE.sha256"

sha256sum -c --status "$BITCODE.sha256" || fail "Checksum mismatch – wrong or corrupted $BITCODE"

##############################################################################
# Sandbox preparation                                                         
##############################################################################

note() {
  printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

##############################################################################
# Common KLEE flags                                                           
##############################################################################
# Create separate sandbox directories for parallel runs
SANDBOX_VANILLA="$(mktemp -d /tmp/${PROG}-vanilla-XXXXXX)"
SANDBOX_EVP="$(mktemp -d /tmp/${PROG}-evp-XXXXXX)"
trap 'rm -rf "$SANDBOX_VANILLA" "$SANDBOX_EVP"' EXIT

KLEE_FLAGS_BASE=(
  --libc=uclibc --posix-runtime --simplify-sym-indices --write-cvcs --write-cov --stats --write-smt2s
  --output-module --max-memory=1000 --disable-inlining --optimize
  --use-forked-solver --use-cex-cache --external-calls=all
  --only-output-states-covering-new
  --max-sym-array-size=4096
  --max-solver-time=30s --max-time=1800s --watchdog --max-memory-inhibit=false
  --max-static-fork-pct=1 --max-static-solve-pct=1 --max-static-cpfork-pct=1
  --switch-type=internal --search=random-path --search=nurs:covnew
  --use-batching-search --batch-instructions=10000
)

# Inject TEST_ENV if it exists
[[ -f "$TEST_ENV" ]] && KLEE_FLAGS_BASE+=( --env-file="$TEST_ENV" )
# Append any caller‑supplied extra KLEE flags
[[ -n "${EXTRA_KLEE_FLAGS:-}" ]] && KLEE_FLAGS_BASE+=( ${EXTRA_KLEE_FLAGS} )

##############################################################################
# Output directory definitions                                                
##############################################################################
OUT_DIR_VANILLA="$UTIL_DIR/klee-vanilla-out-$RUN_ID"
OUT_DIR_EVP="$UTIL_DIR/klee-evp-out-$RUN_ID"

##############################################################################
# Run helpers                                                                 
##############################################################################
prepare_sandbox() {
  local sandbox_dir="$1"
  log "Preparing sandbox $sandbox_dir"
  rm -rf "$sandbox_dir"
  mkdir -p "$sandbox_dir/dirA/subdir"
  printf 'hello' > "$sandbox_dir/dirA/a.txt"
  printf 'world' > "$sandbox_dir/dirA/subdir/b.txt"
}

##############################################################################
# Symbolic input configuration (per utility)
##############################################################################
get_symbolic_input() {
  local prog="$PROG"
  case "$prog" in
    ls)     echo "--sym-args 0 2 8 --sym-files 1 32" ;;    # directory listings, options
    touch)  echo "--sym-args 0 2 8 --sym-files 1 16" ;;    # filenames + optional flags
    cp)     echo "--sym-args 2 2 8 --sym-files 2 32" ;;    # src + dst + file contents
    du)     echo "--sym-args 0 1 8 --sym-files 1 32" ;;    # directory paths + metadata
    stat)   echo "--sym-args 1 1 8" ;;                     # filename input only
    chmod)  echo "--sym-args 2 2 8 --sym-files 1 16" ;;    # mode + target file
    sort)   echo "--sym-args 0 4 8 --sym-stdin 2048 --sym-files 2 4096 A B" ;;    # file lines + sort flags
    mv)     echo "--sym-args 2 2 8 --sym-files 2 16" ;;    # src + dst + small files
    ln)     echo "--sym-args 2 2 8" ;;                     # src + link name
    shred)  echo "--sym-files 1 32 --sym-args 0 1 8" ;;    # file content + options
    wc)     echo "--sym-args 0 6 10 --sym-stdin 4096 --sym-files 3 4096 A B C" ;;
    tail)   echo "--sym-args 0 6 12 --sym-stdin 4096 --sym-files 3 4096 -- A B C" ;;
    *)      echo "--sym-args 0 2 8 --sym-files 1 16" ;;    # safe fallback
  esac
}

run_vanilla() {
  prepare_sandbox "$SANDBOX_VANILLA"
  mkdir -p "$UTIL_DIR"
  rm -rf "$OUT_DIR_VANILLA"
  log "Starting vanilla KLEE run → $OUT_DIR_VANILLA"
  
  local KLEE_FLAGS=("${KLEE_FLAGS_BASE[@]}" --run-in-dir="$SANDBOX_VANILLA")
  
  "$KLEE_BIN" "${KLEE_FLAGS[@]}" --output-dir="$OUT_DIR_VANILLA" "$BITCODE" \
    $(get_symbolic_input) \
    "${EXTRA_PROG_ARGS[@]}" 2>&1 | tee -a "$LOG_FILE"
  local cnt=$(find "$OUT_DIR_VANILLA" -type f -name 'test*.ktest' | wc -l || true)
  log "vanilla completed; generated $cnt ktests"
}

run_evp() {
  prepare_sandbox "$SANDBOX_EVP"
  mkdir -p "$UTIL_DIR"
  rm -rf "$OUT_DIR_EVP"
  log "Starting EVP KLEE run → $OUT_DIR_EVP"
  
  local KLEE_FLAGS=("${KLEE_FLAGS_BASE[@]}" --run-in-dir="$SANDBOX_EVP")
  
"$KLEE_BIN" --use-vase --vase-map="$MAP_FILE" "${KLEE_FLAGS[@]}" \
    --output-dir="$OUT_DIR_EVP" "$BITCODE" \
    $(get_symbolic_input) \
    "${EXTRA_PROG_ARGS[@]}" 2>&1 | tee -a "$LOG_FILE"
  local cnt=$(find "$OUT_DIR_EVP" -type f -name 'test*.ktest' | wc -l || true)
  log "EVP completed; generated $cnt ktests"
}

##############################################################################
# Main                                                                        
##############################################################################
# Main logic starts here
main() {
  # Run both KLEE variants in parallel
  log "Starting parallel KLEE runs..."
  run_vanilla &
  VANILLA_PID=$!
  
  run_evp &
  EVP_PID=$!
  
  # Wait for both processes to complete
  log "Waiting for vanilla KLEE (PID: $VANILLA_PID) to complete..."
  wait $VANILLA_PID
  VANILLA_EXIT=$?
  
  log "Waiting for EVP KLEE (PID: $EVP_PID) to complete..."
  wait $EVP_PID
  EVP_EXIT=$?
  
  # Check exit codes
  if [[ $VANILLA_EXIT -ne 0 ]]; then
    log "WARNING: Vanilla KLEE run failed with exit code $VANILLA_EXIT"
  fi
  
  if [[ $EVP_EXIT -ne 0 ]]; then
    log "WARNING: EVP KLEE run failed with exit code $EVP_EXIT"
  fi
  
  log "All KLEE runs for utility '$PROG' completed (run‑id $RUN_ID)"
}

main

note "done. See $LOG_FILE"
note "done. see $OUT_DIR_EVP"
note "done. see $OUT_DIR_VANILLA"