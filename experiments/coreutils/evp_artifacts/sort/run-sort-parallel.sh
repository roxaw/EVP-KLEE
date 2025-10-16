#!/usr/bin/env bash
set -euo pipefail

KLEE=/home/roxana/klee-env/klee-source/klee/build/bin/klee
BC=~/Downloads/klee-mm-benchmarks/coreutils/coreutils-8.31/obj-llvm/sort_patched.bc
MAP=./limitedValuedMap.json

# Output dirs
OUT_VASE=klee-out-vase
OUT_PLAIN=klee-out-plain

# Clean old outputs if they exist
rm -rf $OUT_VASE $OUT_PLAIN

echo "[INFO] Launching KLEE runs in parallel..."

# --- Run with VASE ---
$KLEE \
  --use-vase --vase-map=$MAP \
  --max-time=1800s --max-solver-time=30s \
  --search=nurs:covnew \
  --libc=uclibc --posix-runtime \
  --output-dir=$OUT_VASE \
  $BC --sym-stdin 16 --sym-args 0 2 4 > vase.log 2>&1 &

PID_VASE=$!

# --- Run without VASE ---
$KLEE \
  --max-time=1800s --max-solver-time=30s \
  --search=nurs:covnew \
  --libc=uclibc --posix-runtime \
  --output-dir=$OUT_PLAIN \
  $BC --sym-stdin 16 --sym-args 0 2 4 > plain.log 2>&1 &

PID_PLAIN=$!

# Wait for both to finish
wait $PID_VASE $PID_PLAIN

echo "[INFO] Both runs finished."

# --- Summary ---
for OUT in $OUT_VASE $OUT_PLAIN; do
  echo "---- Results from $OUT ----"
  if [[ -f "$OUT/info" ]]; then
    grep -E "completed paths|generated tests|total instructions" "$OUT/info" || true
  else
    echo "No info file found in $OUT"
  fi
done

echo "[DONE] Logs saved to vase.log and plain.log"
