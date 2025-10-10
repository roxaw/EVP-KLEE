#!/usr/bin/env bash
# Run any coreutils utility under vanilla KLEE (no EVP).
# Usage:
#   ./run_vanilla.sh <utility> [-- extra app args...]
#
# Env overrides (optional):
#   KLEE_BIN=/path/to/klee
#   ROOT=/home/roxana/Downloads/klee-mm-benchmarks/coreutils
#   COREUTILS_DIR=$ROOT/coreutils-8.31
#   OBJ_SRC=$COREUTILS_DIR/obj-llvm/src
#   ARTIFACTS_DIR=$ROOT/evp_artifacts/<prog>
#   TEST_ENV=$ROOT/evp_artifacts/coreutils/test.env
#   KLEE_OUT_BASE=$ROOT/klee-runs
#   KLEE_MAX_TIME=180s  KLEE_MAX_SOLVER_TIME=30s  KLEE_MEM_MB=1000
#   KLEE_EXTRA_OPTS='--max-tests=0'    # any extra KLEE options
#
set -euo pipefail

die(){ echo "ERROR: $*" >&2; exit 1; }
note(){ echo "[INFO] $*"; }

PROG="${1:-}"; shift || true
[[ -n "$PROG" ]] || die "Usage: $0 <utility> [-- extra app args]"

# Defaults (override via env)
: "${ROOT:=${HOME}/Downloads/klee-mm-benchmarks/coreutils}"
: "${COREUTILS_DIR:=${ROOT}/coreutils-8.31}"
: "${OBJ_SRC:=${COREUTILS_DIR}/obj-llvm/src}"
: "${ARTIFACTS_DIR:=${ROOT}/evp_artifacts/${PROG}}"
: "${TEST_ENV:=${ROOT}/evp_artifacts/coreutils/test.env}"
: "${KLEE_OUT_BASE:=${ROOT}/klee-runs}"
: "${KLEE_BIN:=/home/roxana/klee-env/klee-source/klee/build/bin/klee}"
: "${KLEE_MAX_TIME:=180s}"
: "${KLEE_MAX_SOLVER_TIME:=30s}"
: "${KLEE_MEM_MB:=1000}"
: "${KLEE_EXTRA_OPTS:=}"

command -v "$KLEE_BIN" >/dev/null 2>&1 || die "klee not found at $KLEE_BIN"
command -v extract-bc >/dev/null 2>&1 || die "extract-bc not in PATH"

[[ -x "${OBJ_SRC}/${PROG}" ]] || die "Binary not found: ${OBJ_SRC}/${PROG}"
mkdir -p "$ARTIFACTS_DIR"

BC_BASE="${ARTIFACTS_DIR}/${PROG}.base.bc"
if [[ ! -f "$BC_BASE" ]]; then
  note "Extracting bitcode -> $BC_BASE"
  ( cd "$OBJ_SRC" && extract-bc -o "$BC_BASE" "./${PROG}" )
fi
[[ -f "$BC_BASE" ]] || die "Missing bitcode: $BC_BASE"

# App args (after optional --)
APP_ARGS=()
if [[ "${1:-}" == "--" ]]; then shift; APP_ARGS=("$@"); fi

# Per-run sandbox + output
RUN_TAG="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR_VANILLA="${KLEE_OUT_BASE}/${PROG}/vanilla-${RUN_TAG}"
SANDBOX="$(mktemp -d /tmp/${PROG}-vanilla-XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT

note "Output -> $OUT_DIR_VANILLA"
mkdir -p "$OUT_DIR_VANILLA"
[[ -f "$TEST_ENV" ]] || note "Warning: env file missing ($TEST_ENV); continuing without it"

# KLEE invocation (vanilla)
"$KLEE_BIN" \
  --libc=uclibc --posix-runtime \
  --simplify-sym-indices --write-cvcs --write-cov --output-module \
  --max-memory="$KLEE_MEM_MB" --disable-inlining --optimize --use-forked-solver \
  --use-cex-cache --external-calls=all --only-output-states-covering-new \
  ${TEST_ENV:+--env-file="$TEST_ENV"} \
  --run-in-dir="$SANDBOX" \
  --max-sym-array-size=4096 \
  --max-solver-time="$KLEE_MAX_SOLVER_TIME" \
  --max-time="$KLEE_MAX_TIME" \
  --watchdog --max-memory-inhibit=false \
  --max-static-fork-pct=1 --max-static-solve-pct=1 --max-static-cpfork-pct=1 \
  --switch-type=internal \
  --search=random-path --search=nurs:covnew \
  --use-batching-search --batch-instructions=10000 \
  --output-dir="$OUT_DIR_VANILLA" \
  "$BC_BASE" \
  -- "${APP_ARGS[@]}"

note "Done. See $OUT_DIR_VANILLA"
