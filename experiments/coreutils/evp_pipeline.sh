#!/usr/bin/env bash
set -euo pipefail

# --- 1. Get Utility Name ---
UTILITY="${1:-}"
if [[ -z "$UTILITY" ]]; then
  echo "Usage: $0 <utility>" >&2
  exit 1
fi

echo "🚀 Starting EVP pipeline for utility: $UTILITY"

# --- 2. Get Thresholds from User ---
read -p "Enter max values for map generation [default: 3]: " MAX_VALUES
MAX_VALUES=${MAX_VALUES:-3}

read -p "Enter min occurrence for map generation [default: 5]: " MIN_OCCURRENCE
MIN_OCCURRENCE=${MIN_OCCURRENCE:-5}

echo "⚙️ Using thresholds: max-values=$MAX_VALUES, min-occurrence=$MIN_OCCURRENCE"

# --- 3. Run Instrumentation and Build (Step 1) ---
echo "[1/4] Running collection script (evp_step1_collect.sh)..."
if [[ ! -x "./evp_step1_collect.sh" ]]; then
    echo "Error: evp_step1_collect.sh not found or not executable." >&2
    exit 1
fi
./evp_step1_collect.sh "$UTILITY"


# --- 4. Run Test Harness to Generate Logs ---
echo "[2/4] Running test harness (test-harness-generic.sh)..."
if [[ ! -x "./test-harness-generic.sh" ]]; then
    echo "Error: test-harness-generic.sh not found or not executable." >&2
    exit 1
fi

# For utilities requiring root, we must run the harness with sudo.
if [[ "$UTILITY" == "chown" || "$UTILITY" == "chgrp" ]]; then
    echo "INFO: Using sudo for test harness for $UTILITY due to permissions."
    sudo -E ./test-harness-generic.sh "$UTILITY"
else
    ./test-harness-generic.sh "$UTILITY"
fi

# --- 5. Verify Value Log ---
echo "[3/4] Verifying value log..."
VASE_LOG="./evp_artifacts/$UTILITY/vase_value_log.txt"

if [[ ! -f "$VASE_LOG" ]]; then
    echo "Error: VASE log file was not created at $VASE_LOG" >&2
    exit 1
fi

if [[ ! -s "$VASE_LOG" ]]; then
    echo "Warning: VASE log file is empty. Map generation may produce an empty map." >&2
else
    LOG_LINES=$(wc -l < "$VASE_LOG")
    echo "✅ Success: VASE log created with $LOG_LINES lines."
fi

# --- 6. Generate Value Map ---
echo "[4/4] Generating limited value map..."
if [[ ! -f "./generate_limited_map.py" ]]; then
    echo "Error: generate_limited_map.py not found." >&2
    exit 1
fi

python3 generate_limited_map.py \
  --log "$VASE_LOG" \
  --out "./evp_artifacts/$UTILITY/limitedValuedMap.json" \
  --max-values "$MAX_VALUES" \
  --min-occurrence "$MIN_OCCURRENCE"

echo "🎉 Pipeline finished for $UTILITY!"
echo "Final map: ./evp_artifacts/$UTILITY/limitedValuedMap.json"
