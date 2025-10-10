#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

UTILITY="${1:-${UTILITY:-}}"
if [[ -z "$UTILITY" ]]; then
  echo "Usage: $0 <utility>"; exit 1; fi

# === CONFIG ===
ROOT="${ROOT:-/home/roxana/Downloads/klee-mm-benchmarks/coreutils}"
CU="${CU:-$ROOT/coreutils-8.31}"
BUILD_DIR="$CU/obj-llvm"           # configured build tree
OBJ_SRC="$BUILD_DIR/src"           # path that tests expect
INST="${INST:-$BUILD_DIR/instrumented}"
FINAL_EXE="$INST/${UTILITY}_final_exe"
ENV_SH="${ENV_SH:-$ROOT/testing-env.sh}"

# Default artifacts/log dir aligns with evp_step1_collect.sh: per-utility subdir
if [[ -z "${VASE_DIR:-}" ]]; then
  VASE_DIR="$ROOT/evp_artifacts/$UTILITY"
fi
VASE_LOG="${VASE_LOG:-$VASE_DIR/vase_value_log.txt}"

# Raise open-file limit for big test suites
ulimit -n 10000 || true

# Sanity checks
[[ -x "$FINAL_EXE" ]] || { echo "ERR: $FINAL_EXE not found/executable"; exit 1; }
[[ -f "$ENV_SH" ]] || echo "WARN: $ENV_SH not found; continuing without it"
[[ -d "$VASE_DIR" ]] || mkdir -p "$VASE_DIR"
[[ -d "$OBJ_SRC"  ]] || { echo "ERR: $OBJ_SRC missing"; exit 1; }

# Ensure log target is a file under the per-utility directory
mkdir -p "$VASE_DIR"
: > "$VASE_LOG"
if [[ -d "$VASE_LOG" ]]; then echo "ERR: VASE_LOG is a directory"; exit 1; fi

# Make the tests pick the instrumented binary
ln -sfn "$FINAL_EXE" "$OBJ_SRC/$UTILITY"           # overwrite symlink only, original preserved
export PATH="$INST:$PATH"

# Load stable env if present
set -a; [[ -f "$ENV_SH" ]] && . "$ENV_SH"; set +a

# Skip utilities known to hang entirely
case "$UTILITY" in
  basenc)
    echo "[SKIP] $UTILITY is known to hang – skipping entire utility suite"
    exit 0 ;;
  *) ;;
esac

# Where the coreutils tests for this utility live
TEST_DIR="$CU/tests-latest/$UTILITY"
[[ -d "$TEST_DIR" ]] || { echo "ERR: no tests found at $TEST_DIR"; exit 1; }

LOG_DIR="$ROOT/test-logs/$UTILITY"
mkdir -p "$LOG_DIR"

cd "$CU"

# Handle permission-sensitive utilities
case "$UTILITY" in
  chown|chgrp)
    echo "[WARN] $UTILITY requires root for most tests - using limited test set"
    TEST_FILTER="basic deref"
    ;;
  cat)
    chmod -R +r "$TEST_DIR" 2>/dev/null || true
    ;;
esac

echo "[INFO] Running $UTILITY tests from $TEST_DIR"
for t in "$TEST_DIR"/*.{sh,pl}; do
  # glob might not match
  [[ ! -e $t ]] && continue

  base=$(basename "$t")

  # Skip privileged tests if TEST_FILTER is set
  if [[ -n "${TEST_FILTER:-}" ]]; then
    if ! echo "$base" | grep -qE "$TEST_FILTER"; then
      echo "[SKIP] $t (requires privileges)"
      continue
    fi
  fi

  # Decide srcdir heuristic (matches upstream tests' expectation)
  case "$(sed -n '1,20p' "$t")" in
    *'/tests/init.sh'*) SRC='.' ;;
    *)                  SRC='tests' ;;
  esac

  # Utility-specific knobs (extend as needed)
  EXTRA_ENV=()
  case "$UTILITY" in
    rm) EXTRA_ENV+=(RM_OPT='-f');;
    *)  ;;
  esac

  # choose interpreter
  case "$t" in
    *.sh) runner=bash ;;
    *.pl) runner=perl ;;
  esac

  echo "[RUN] $t (srcdir=$SRC, runner=$runner)"
  if ! VASE_LOG="$VASE_LOG" \
         built_programs=" $UTILITY " srcdir="$SRC" VERBOSE=yes "${EXTRA_ENV[@]}" \
         timeout 30s "$runner" "$t" > "$LOG_DIR/${base}.out" 2> "$LOG_DIR/${base}.err"; then
    rc=$?
    # timeout(1) returns 124 when the command times out
    if [[ $rc -eq 124 ]]; then
      echo "[TIMEOUT] $base stuck >30s"
    fi
  fi
done

# Summary
echo "---- VASE value log (per-run) ----"
ls -lh "$VASE_LOG" || true
wc -l "$VASE_LOG" || true

echo "---- Failures (if any) ----"
grep -Hn "FAIL" "$LOG_DIR/"*.out 2>/dev/null || echo "(no FAIL lines seen in .out)"
grep -Hn "fopen VASE_LOG: Is a directory" "$LOG_DIR/"*.err 2>/dev/null || true

echo "[DONE] $UTILITY harness completed."
echo "[TIP] View logs under: $LOG_DIR"