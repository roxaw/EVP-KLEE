#!/usr/bin/env bash
# EVP/VASE pipeline (Step 1–3) for any coreutils utility
# Value Collection -> Map Generation -> Symbolic Execution (vanilla & EVP)

set -euo pipefail

# Usage: ./evp_pipeline_step1.sh <utility>
PROG=${1:-}
if [[ -z "${PROG}" ]]; then
  echo "Usage: $0 <utility>" >&2
  exit 1
fi

# Tooling (override via env if needed)
export CLANG=${CLANG:-/usr/lib/llvm-10/bin/clang}
export OPT=${OPT:-/usr/lib/llvm-10/bin/opt}
export LLVMLINK=${LLVMLINK:-/usr/lib/llvm-10/bin/llvm-link}
export PASS_SO=${PASS_SO:-/home/roxana/VASE-klee/vasepass/libVaseInstrumentPass.so}

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COREUTILS_DIR="${SCRIPT_DIR}/coreutils-8.31"
OBJ_SRC="${COREUTILS_DIR}/obj-llvm/src"
ARTIFACTS_DIR="${SCRIPT_DIR}/evp_artifacts/${PROG}"

# Artifact names (stored under ARTIFACTS_DIR)
BC_BASE="${PROG}.base.bc"
BC_INSTR="${PROG}.evpinstr.bc"
BC_FINAL="${PROG}_final.bc"
EXE_FINAL="${PROG}_final_exe"
SHA_FILE="${ARTIFACTS_DIR}/${PROG}.base.bc.sha256"
LOGGER_BC="logger.bc"

mkdir -p "${ARTIFACTS_DIR}"

# ---- Step 1: Value Collection (instrument & run tests) ---------------------

# 1) Extract uninstrumented program -> <prog>.base.bc (into ARTIFACTS_DIR)
cd "${OBJ_SRC}"
command -v extract-bc >/dev/null 2>&1 || { echo "Error: extract-bc not found." >&2; exit 1; }
[[ -x "./${PROG}" ]] || { echo "Error: binary not found: ${OBJ_SRC}/${PROG}" >&2; exit 1; }
extract-bc -o "${ARTIFACTS_DIR}/${BC_BASE}" "./${PROG}"

# 2) Record checksum
sha256sum "${ARTIFACTS_DIR}/${BC_BASE}" | tee "${SHA_FILE}"

# 3) Instrument with your pass -> <prog>.evpinstr.bc
"${OPT}" -load "${PASS_SO}" -vase-instrument \
  "${ARTIFACTS_DIR}/${BC_BASE}" -o "${ARTIFACTS_DIR}/${BC_INSTR}"

# 4) Build the logger as bitcode -> logger.bc (in ARTIFACTS_DIR)
"${CLANG}" -O0 -emit-llvm -c /home/roxana/VASE-klee/logger.c -o "${ARTIFACTS_DIR}/${LOGGER_BC}"

# 5) Link instrumented bitcode + logger -> <prog>_final.bc
"${LLVMLINK}" "${ARTIFACTS_DIR}/${BC_INSTR}" "${ARTIFACTS_DIR}/${LOGGER_BC}" \
  -o "${ARTIFACTS_DIR}/${BC_FINAL}"

# 6) Build final executable in obj-llvm/src -> <prog>_final_exe
EXTRA="$(pkg-config --libs --silence-errors libacl libattr || true)"
"${CLANG}" "${ARTIFACTS_DIR}/${BC_FINAL}" -o "${EXE_FINAL}" -ldl -lpthread -lselinux -lcap ${EXTRA:-}

# 7) Swap the binary in-place (symlink), backing up the original once
if [[ -f "${PROG}" && ! -f "${PROG}.orig" ]]; then
  cp -a "${PROG}" "${PROG}.orig" || echo "Warning: failed to backup ${PROG}" >&2
fi
rm -f "${PROG}"
ln -sfn "$(pwd)/${EXE_FINAL}" "./${PROG}"

# 8) Run optional per-utility harness to collect values (if present)
HARNESS="${SCRIPT_DIR}/test_harness.sh"
if [[ -x "${HARNESS}" ]]; then
  "${HARNESS}" "${PROG}" || echo "Warning: ${HARNESS} exited non-zero" >&2
else
  echo "Warning: Test harness not found: ${HARNESS}" >&2
fi

# Consolidate scattered logs (logger may write relative 'vase_value_log.txt')
CANON_LOG="${ARTIFACTS_DIR}/vase_value_log.txt"
rm -f "${CANON_LOG}"
# harvest from source tree and temp dirs that might be used by tests
find "${COREUTILS_DIR}" -type f -name 'vase_value_log.txt' -size +0c -exec cat {} + >> "${CANON_LOG}" 2>/dev/null || true
# Optional: also harvest from /tmp if desired (commented to avoid noise)
# find /tmp -maxdepth 2 -type f -name 'vase_value_log.txt' -size +0c -exec cat {} + >> "${CANON_LOG}" 2>/dev/null || true
: > "${CANON_LOG}"  # ensure file exists even if nothing was found (keeps downstream happy)
if [[ ! -s "${CANON_LOG}" ]]; then
  echo "Warning: No VASE log entries found; ${CANON_LOG} is empty." >&2
fi

# ---- Step 2: Map Generation (JSON) -----------------------------------------

cd "${SCRIPT_DIR}"
python3 generate_limited_map.py \
  --log "${CANON_LOG}" \
  --out "${ARTIFACTS_DIR}/limitedValuedMap.json" \
  --max-values 3 \
  --min-occurrence 5 || echo "Warning: Map generation exited non-zero" >&2

# Ensure test.env exists for KLEE runs
mkdir -p "${SCRIPT_DIR}/evp_artifacts/coreutils"
if [[ -f "${SCRIPT_DIR}/test.env" ]]; then
  cp "${SCRIPT_DIR}/test.env" "${SCRIPT_DIR}/evp_artifacts/coreutils/test.env"
else
  echo "Warning: test.env not found; creating empty one for KLEE" >&2
  touch "${SCRIPT_DIR}/evp_artifacts/coreutils/test.env"
fi
