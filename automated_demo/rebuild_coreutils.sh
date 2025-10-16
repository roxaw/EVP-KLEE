#!/usr/bin/env bash
set -euo pipefail

echo "=== Rebuilding Coreutils with Correct Paths ==="

# Get project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CU="$PROJECT_ROOT/benchmarks/coreutils-8.31"

echo "[INFO] Project root: $PROJECT_ROOT"
echo "[INFO] Coreutils dir: $CU"

# Check if coreutils source exists
if [[ ! -d "$CU" ]]; then
  echo "ERR: Coreutils directory not found: $CU"
  exit 1
fi

cd "$CU"

# Clean previous build
echo "[STEP 1] Cleaning previous build..."
if [[ -d "obj-llvm" ]]; then
  rm -rf obj-llvm
  echo "[OK] Removed old build directory"
fi

# Create new build directory
echo "[STEP 2] Creating new build directory..."
mkdir -p obj-llvm
cd obj-llvm

# Configure with correct paths
echo "[STEP 3] Configuring build..."
CC=wllvm ../configure --disable-nls CFLAGS="-g"

# Build
echo "[STEP 4] Building coreutils..."
make -j$(nproc)

# Extract bitcode for all utilities
echo "[STEP 5] Extracting bitcode for all utilities..."
cd src

# Get list of utilities from config
UTILITIES=("echo" "ls" "cp" "chmod" "mkdir" "rm" "mv" "dd" "df" "du" "ln" "split" "touch" "rmdir")

for util in "${UTILITIES[@]}"; do
  if [[ -x "./$util" ]]; then
    echo "[EXTRACT] $util"
    extract-bc -o "${util}.bc" "./$util" || echo "[WARN] Failed to extract $util"
  else
    echo "[SKIP] $util not found"
  fi
done

echo ""
echo "=== COREUTILS REBUILD COMPLETED ==="
echo "[OK] Coreutils rebuilt with correct paths"
echo "[INFO] Build directory: $CU/obj-llvm"
echo "[INFO] Binaries: $CU/obj-llvm/src/"
echo ""
echo "Now you can run Phase 1:"
echo "  ./test_phase1.sh echo"
