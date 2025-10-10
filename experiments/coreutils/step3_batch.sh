#!/usr/bin/env bash
# step3_batch.sh — Run a set of utilities sequentially through step3_generic.sh

set -euo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
GENERIC="$SCRIPT_DIR/step3_generic.sh"

# List of benchmark utilities
UTILS=(wc tail cp stat chmod mv ln shred du touch)

RUN_ID=$(date -u +%Y%m%d-%H%M%S)

for u in "${UTILS[@]}"; do
  echo "=========================================================="
  echo ">>> Running $u (run-id: $RUN_ID)"
  echo "=========================================================="
  "$GENERIC" "$u" "$RUN_ID"
done

echo "All batch runs completed (run-id: $RUN_ID)"
