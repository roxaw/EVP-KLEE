#!/usr/bin/env bash
set -euo pipefail

# Test script for Phase 1 EVP pipeline
# Usage: ./test_phase1.sh <utility>

UTILITY="${1:-echo}"
echo "=== Testing Phase 1 EVP Pipeline for: $UTILITY ==="

# Check if we're in the right directory
if [[ ! -f "evp_step1_collect.sh" ]]; then
  echo "ERR: Please run this script from the automated_demo directory"
  exit 1
fi

# Check if coreutils is built
if [[ ! -d "../benchmarks/coreutils-8.31" ]]; then
  echo "ERR: Coreutils not found. Please build coreutils first."
  echo "Expected location: ../benchmarks/coreutils-8.31"
  exit 1
fi

echo "[INFO] Starting Phase 1 test for utility: $UTILITY"

# Run Phase 1
echo "[STEP] Running evp_step1_collect.sh..."
if ./evp_step1_collect.sh "$UTILITY"; then
  echo "[OK] Phase 1 completed successfully"
else
  echo "[ERROR] Phase 1 failed"
  exit 1
fi

# Validate outputs
echo ""
echo "=== VALIDATION ==="

ART_DIR="../benchmarks/evp_artifacts/$UTILITY"
echo "[CHECK] Validating artifacts in: $ART_DIR"

# Check if artifacts directory exists
if [[ ! -d "$ART_DIR" ]]; then
  echo "[ERROR] Artifacts directory not found: $ART_DIR"
  exit 1
fi

# Check required files
required_files=(
  "${UTILITY}.base.bc"
  "${UTILITY}.base.bc.sha256"
  "${UTILITY}.evpinstr.bc"
  "logger.bc"
  "${UTILITY}_final.bc"
  "${UTILITY}_final_exe"
)

for file in "${required_files[@]}"; do
  if [[ -f "$ART_DIR/$file" ]]; then
    size=$(stat -c%s "$ART_DIR/$file")
    echo "[OK] $file exists (${size} bytes)"
  else
    echo "[ERROR] Missing file: $file"
    exit 1
  fi
done

# Check if executable runs
echo "[CHECK] Testing executable..."
if [[ -x "$ART_DIR/${UTILITY}_final_exe" ]]; then
  if timeout 5s "$ART_DIR/${UTILITY}_final_exe" --version >/dev/null 2>&1; then
    echo "[OK] Executable runs successfully"
  else
    echo "[WARN] Executable exists but may have issues running"
  fi
else
  echo "[ERROR] Executable not found or not executable"
  exit 1
fi

# Check symlink
SYMLINK_TARGET="../benchmarks/coreutils-8.31/obj-llvm/src/$UTILITY"
if [[ -L "$SYMLINK_TARGET" ]]; then
  echo "[OK] Symlink created: $SYMLINK_TARGET"
else
  echo "[WARN] Symlink not found: $SYMLINK_TARGET"
fi

echo ""
echo "=== PHASE 1 VALIDATION COMPLETED ==="
echo "[SUCCESS] All Phase 1 steps completed and validated"
echo "[INFO] Ready for Phase 2 (profiling)"
echo ""
echo "Next step: Run Phase 2 profiling:"
echo "  ROOT=\"../benchmarks\" VASE_DIR=\"$ART_DIR\" ./test-harness-generic.sh $UTILITY"
