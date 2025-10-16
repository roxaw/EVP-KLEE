#!/usr/bin/env bash
set -euo pipefail

echo "=== Fixing Coreutils Path References ==="

# Create the old path structure that coreutils expects
OLD_PATH="/home/roxana/VASE-klee/EVP-KLEE/EVP-KLEE/benchmarks/coreutils-8.31"
NEW_PATH="/home/roxana/VASE-klee/EVP-KLEE/benchmarks/coreutils-8.31"

echo "[INFO] Creating symlink for old path structure..."
echo "[INFO] Old path: $OLD_PATH"
echo "[INFO] New path: $NEW_PATH"

# Create parent directories
mkdir -p "$(dirname "$OLD_PATH")"

# Create symlink
if [[ -L "$OLD_PATH" ]]; then
  echo "[INFO] Symlink already exists, removing..."
  rm "$OLD_PATH"
fi

ln -sf "$NEW_PATH" "$OLD_PATH"
echo "[OK] Symlink created: $OLD_PATH -> $NEW_PATH"

# Verify the symlink works
if [[ -d "$OLD_PATH/obj-llvm/src" ]]; then
  echo "[OK] Symlink verified - coreutils accessible at old path"
else
  echo "[ERROR] Symlink verification failed"
  exit 1
fi

echo ""
echo "=== PATH FIX COMPLETED ==="
echo "[OK] Coreutils now accessible at both old and new paths"
echo ""
echo "Now you can run Phase 1:"
echo "  ./test_phase1.sh echo"
