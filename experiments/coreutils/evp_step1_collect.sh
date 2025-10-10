#!/usr/bin/env bash
set -euo pipefail

# Usage: ./evp_step1_collect.sh <utility>
UTILITY="${1:-${UTILITY:-}}"
if [[ -z "$UTILITY" ]]; then
  echo "Usage: $0 <utility>"; exit 1; fi

# --- Config (override via env) ---
CLANG="${CLANG:-/usr/lib/llvm-10/bin/clang}"
OPT="${OPT:-/usr/lib/llvm-10/bin/opt}"
LLVMLINK="${LLVMLINK:-/usr/lib/llvm-10/bin/llvm-link}"
PASS_SO="${PASS_SO:-/home/roxana/VASE-klee/vasepass/libVaseInstrumentPass.so}"
LOGGER_C="${LOGGER_C:-/home/roxana/VASE-klee/logger.c}"
ROOT="${ROOT:-/home/roxana/Downloads/klee-mm-benchmarks/coreutils}"
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

# Move into build tree and verify utility exists
cd "$OBJ_SRC"
[[ -x "./$UTILITY" ]] || { echo "ERR: binary not found: $OBJ_SRC/$UTILITY"; exit 1; }

# 1. Freeze pristine bitcode exactly once
BASE_BC="$ART_UTIL_DIR/${UTILITY}.base.bc"
if [[ -e "$BASE_BC" ]]; then
  echo "[SKIP] Using existing canonical bitcode: $BASE_BC"
else
  extract-bc -o "$BASE_BC" "./${UTILITY}"
  sha256sum "$BASE_BC" | tee "$BASE_BC.sha256"
fi

# 2. Instrument the frozen bitcode
INSTR_BC="$ART_UTIL_DIR/${UTILITY}.evpinstr.bc"
"$OPT" -load "$PASS_SO" -vase-instrument "$BASE_BC" -o "$INSTR_BC"

# 3. Build logger runtime
"$CLANG" -O0 -emit-llvm -c "$LOGGER_C" -o "$ART_UTIL_DIR/logger.bc"

# 4. Link instrumented utility with logger
FINAL_BC="$ART_UTIL_DIR/${UTILITY}_final.bc"
"$LLVMLINK" "$INSTR_BC" "$ART_UTIL_DIR/logger.bc" -o "$FINAL_BC"

# 5. Build final executable
EXTRA="$(pkg-config --libs --silence-errors libacl libattr)"
FINAL_EXE="$ART_UTIL_DIR/${UTILITY}_final_exe"
"$CLANG" "$FINAL_BC" -o "$FINAL_EXE" -ldl -lpthread -lselinux -lcap $EXTRA

# 6. Stage copy for harness convenience (does *not* overwrite the original binary)
install -m 0755 "$FINAL_EXE" "$INST_DIR/${UTILITY}_final_exe"

# 7. Swap the binary in-place (symlink), backing up the original once
echo "[OK] Built and installed instrumented $UTILITY at: $OBJ_SRC/$UTILITY"
echo "[INFO] Artifacts stored under: $ART_UTIL_DIR"
echo "[TIP] Run: ROOT=\"$ROOT\" VASE_DIR=\"$ART_UTIL_DIR\" $ROOT/test-harness-generic.sh $UTILITY"

cd $ROOT
python3 generate_limited_map.py \
--log $ART_UTIL_DIR/vase_value_log.txt \
--out "$ART_UTIL_DIR/limitedValuedMap.json" \
--max-values 4 \
--min-occurrence 10
echo "[DONE] Generated limited value map at: $ART_UTIL_DIR/limitedValuedMap.json"