#!/usr/bin/env bash
set -euo pipefail

# Usage: ./evp_step1_collect.sh <utility>
UTILITY="${1:-${UTILITY:-}}"
if [[ -z "$UTILITY" ]]; then
  echo "Usage: $0 <utility>"; exit 1; fi

# --- Config (override via env) ---
# Get project root (parent of automated_demo directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CLANG="${CLANG:-/usr/lib/llvm-10/bin/clang}"
OPT="${OPT:-/usr/lib/llvm-10/bin/opt}"
LLVMLINK="${LLVMLINK:-/usr/lib/llvm-10/bin/llvm-link}"
PASS_SO="${PASS_SO:-$PROJECT_ROOT/automated_demo/tools/vasepass/libVaseInstrumentPass.so}"
LOGGER_C="${LOGGER_C:-$PROJECT_ROOT/automated_demo/tools/logger/logger.c}"
ROOT="${ROOT:-$PROJECT_ROOT/benchmarks}"
CU="${CU:-$ROOT/coreutils-8.31}"
BUILD_DIR="$CU/obj-llvm"
OBJ_SRC="$CU/obj-llvm/src"
INST_DIR="$CU/obj-llvm/instrumented"
ART_DIR="$ROOT/evp_artifacts"
ART_UTIL_DIR="$ART_DIR/$UTILITY"

mkdir -p "$ART_DIR" "$ART_UTIL_DIR" "$INST_DIR"

# Tools sanity
for t in "$CLANG" "$OPT" "$LLVMLINK"; do
  [[ -x "$t" ]] || { echo "ERR: tool not executable: $t"; exit 1; }
done
command -v extract-bc >/dev/null 2>&1 || { echo "ERR: extract-bc not found in PATH"; exit 1; }

# Check if coreutils is built
if [[ ! -d "$CU" ]]; then
  echo "ERR: Coreutils directory not found: $CU"
  echo "Please build coreutils first or check the path"
  exit 1
fi

# Move into build tree and verify utility exists
cd "$OBJ_SRC"
[[ -x "./$UTILITY" ]] || { echo "ERR: binary not found: $OBJ_SRC/$UTILITY"; exit 1; }

echo "[INFO] Starting Phase 1 for utility: $UTILITY"
echo "[INFO] Project root: $PROJECT_ROOT"
echo "[INFO] Coreutils dir: $CU"
echo "[INFO] Artifacts dir: $ART_UTIL_DIR"

# 1. Freeze pristine bitcode exactly once
BASE_BC="$ART_UTIL_DIR/${UTILITY}.base.bc"
if [[ -e "$BASE_BC" ]]; then
  echo "[SKIP] Using existing canonical bitcode: $BASE_BC"
else
  echo "[STEP 1] Extracting bitcode for $UTILITY..."
  extract-bc -o "$BASE_BC" "./${UTILITY}"
  sha256sum "$BASE_BC" | tee "$BASE_BC.sha256"
  echo "[OK] Bitcode extracted and checksummed"
fi

# 2. Instrument the frozen bitcode
echo "[STEP 2] Instrumenting bitcode with VASE pass..."
INSTR_BC="$ART_UTIL_DIR/${UTILITY}.evpinstr.bc"
"$OPT" -load "$PASS_SO" -vase-instrument "$BASE_BC" -o "$INSTR_BC"
echo "[OK] Bitcode instrumented"

# 3. Build logger runtime
echo "[STEP 3] Building logger runtime..."
"$CLANG" -O0 -emit-llvm -c "$LOGGER_C" -o "$ART_UTIL_DIR/logger.bc"
echo "[OK] Logger bitcode created"

# 4. Link instrumented utility with logger
echo "[STEP 4] Linking instrumented bitcode with logger..."
FINAL_BC="$ART_UTIL_DIR/${UTILITY}_final.bc"
"$LLVMLINK" "$INSTR_BC" "$ART_UTIL_DIR/logger.bc" -o "$FINAL_BC"
echo "[OK] Final bitcode linked"

# 5. Build final executable
echo "[STEP 5] Building final executable..."
EXTRA="$(pkg-config --libs --silence-errors libacl libattr 2>/dev/null || echo '')"
FINAL_EXE="$ART_UTIL_DIR/${UTILITY}_final_exe"
"$CLANG" "$FINAL_BC" -o "$FINAL_EXE" -ldl -lpthread -lselinux -lcap $EXTRA
echo "[OK] Final executable built"

# 6. Stage copy for harness convenience (does *not* overwrite the original binary)
install -m 0755 "$FINAL_EXE" "$INST_DIR/${UTILITY}_final_exe"
echo "[OK] Executable staged for testing"

# 7. Create symlink for testing (backup original if exists)
if [[ -L "$OBJ_SRC/$UTILITY" ]]; then
  echo "[INFO] Removing existing symlink: $OBJ_SRC/$UTILITY"
  rm "$OBJ_SRC/$UTILITY"
elif [[ -f "$OBJ_SRC/$UTILITY" ]]; then
  echo "[INFO] Backing up original binary: $OBJ_SRC/$UTILITY"
  mv "$OBJ_SRC/$UTILITY" "$OBJ_SRC/${UTILITY}.original"
fi

# Create symlink to instrumented version
ln -sf "$INST_DIR/${UTILITY}_final_exe" "$OBJ_SRC/$UTILITY"
echo "[OK] Symlink created for testing"

echo ""
echo "=== PHASE 1 COMPLETED ==="
echo "[OK] Built and installed instrumented $UTILITY at: $OBJ_SRC/$UTILITY"
echo "[INFO] Artifacts stored under: $ART_UTIL_DIR"
echo "[INFO] Files created:"
echo "  - Base bitcode: $BASE_BC"
echo "  - Instrumented bitcode: $INSTR_BC"
echo "  - Logger bitcode: $ART_UTIL_DIR/logger.bc"
echo "  - Final bitcode: $FINAL_BC"
echo "  - Final executable: $FINAL_EXE"
echo ""
echo "[TIP] Now run Phase 2 (profiling):"
echo "  ROOT=\"$ROOT\" VASE_DIR=\"$ART_UTIL_DIR\" ./test-harness-generic.sh $UTILITY"
