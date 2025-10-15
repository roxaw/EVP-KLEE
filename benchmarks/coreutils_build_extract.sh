#!/bin/bash
set -euo pipefail

# Coreutils build and bitcode extraction + freezing helper
# Usage:
#   coreutils_build_extract.sh <program>|all [--build-only|--extract-only] [--normalize-debug-paths] [--force] [--rebuild-if-missing]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COREUTILS_DIR="$SCRIPT_DIR/coreutils-8.31"
OBJ_DIR="$COREUTILS_DIR/obj-llvm"
SRC_DIR="$OBJ_DIR/src"
FREEZE_DIR="$SCRIPT_DIR/evp_artifacts/coreutils/base_bc"
ARTIFACTS_DIR="$SCRIPT_DIR/evp_artifacts"
LOG_DIR="$ARTIFACTS_DIR/logs"
BUILD_LOG="$OBJ_DIR/build.log"

PROGRAM="${1:-}"
MODE_BUILD_ONLY=0
MODE_EXTRACT_ONLY=0
NORMALIZE_DEBUG=0
FORCE_OVERWRITE=0
REBUILD_IF_MISSING=0
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-only) MODE_BUILD_ONLY=1 ;;
    --extract-only) MODE_EXTRACT_ONLY=1 ;;
    --normalize-debug-paths) NORMALIZE_DEBUG=1 ;;
    --force) FORCE_OVERWRITE=1 ;;
    --rebuild-if-missing) REBUILD_IF_MISSING=1 ;;
    *) echo "[ERROR] Unknown flag: $1" >&2; exit 1 ;;
  esac
  shift || true
done

if [[ -z "$PROGRAM" ]]; then
  echo "Usage: $0 <program>|all [--build-only|--extract-only] [--normalize-debug-paths] [--force]" >&2
  exit 1
fi

# Dependency checks
need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] Missing required tool: $1" >&2
    exit 2
  fi
}

need wllvm
need extract-bc
need sha256sum
need make

mkdir -p "$ARTIFACTS_DIR" "$FREEZE_DIR" "$LOG_DIR" "$OBJ_DIR"

already_built() {
  [[ -f "$OBJ_DIR/config.status" ]] && [[ -d "$SRC_DIR" ]] && ls -1 "$SRC_DIR" 2>/dev/null | grep -q .
}

configure_and_build() {
  if already_built; then
    echo "[SKIP] coreutils already built at $OBJ_DIR"
    return 0
  fi
  echo "=== [coreutils] Configure & Build (wllvm) ==="
  pushd "$OBJ_DIR" >/dev/null
  export LLVM_COMPILER=clang
  CFLAGS="-g -O1 -Xclang -disable-llvm-passes \
          -fno-inline -fno-builtin -fno-omit-frame-pointer \
          -D__NO_STRING_INLINES -D_FORTIFY_SOURCE=0 -U__OPTIMIZE__"
  if [[ "$NORMALIZE_DEBUG" -eq 1 ]]; then
    CFLAGS+=" -fdebug-prefix-map=$(realpath ..)=/src/coreutils-8.31"
  fi
  export CFLAGS
  { CC=wllvm ../configure --disable-nls && make -j"$(nproc)"; } 2>&1 | tee "$BUILD_LOG"
  popd >/dev/null
}

freeze_bc() {
  local src_bc="$1"
  local util="$2"
  local dst_bc="$FREEZE_DIR/$util.base.bc"
  local dst_sha="$FREEZE_DIR/$util.base.bc.sha256"
  if [[ -f "$dst_bc" && $FORCE_OVERWRITE -eq 0 ]]; then
    echo "[SKIP] already frozen: $dst_bc"
    return 0
  fi
  mkdir -p "$FREEZE_DIR"
  cp -f "$src_bc" "$dst_bc"
  (cd "$FREEZE_DIR" && sha256sum "$util.base.bc" > "$dst_sha")
  echo "[FROZEN] $dst_bc"
}

extract_one() {
  local util="$1"
  local bin_path="$SRC_DIR/$util"
  local bc_path="$SRC_DIR/$util.base.bc"
  if [[ ! -x "$bin_path" ]]; then
    if [[ $REBUILD_IF_MISSING -eq 1 ]]; then
      echo "[INFO] Binary missing for $util; rebuilding..."
      configure_and_build
    else
      echo "[WARN] Binary not found or not executable: $bin_path (skipping)"
      return 0
    fi
  fi
  echo "=== [extract-bc] $util ==="
  pushd "$SRC_DIR" >/dev/null
  if command -v extract-bc >/dev/null 2>&1; then
    extract-bc -o "$bc_path" "./$util" || true
  fi
  if [[ ! -f "$bc_path" ]]; then
    # Fallback: use wllvm tool to generate bc via whole-program extraction
    if command -v get-bc >/dev/null 2>&1; then
      get-bc -b -o "$bc_path" "./$util" || true
    fi
  fi
  if [[ ! -f "$bc_path" ]]; then
    echo "[ERROR] Failed to produce bitcode for $util (tried extract-bc and get-bc)." >&2
    popd >/dev/null
    return 1
  fi
  popd >/dev/null
  freeze_bc "$bc_path" "$util"
}

list_utils() {
  python3 - <<'PY'
import json,sys,os
root=os.path.abspath(os.path.join(os.path.dirname(__file__),'..'))
cfg=os.path.join(root,'automated_demo','config','programs.json')
d=json.load(open(cfg))
print('\n'.join(d['coreutils']['programs']))
PY
}

if [[ $MODE_BUILD_ONLY -eq 1 ]]; then
  configure_and_build
  echo "[DONE] Build-only mode completed."
  exit 0
fi

if [[ $MODE_EXTRACT_ONLY -eq 1 ]]; then
  : # skip build
else
  configure_and_build
fi

if [[ "$PROGRAM" == "all" ]]; then
  list_utils | while read -r util; do
    [[ -z "$util" ]] && continue
    extract_one "$util"
  done
else
  extract_one "$PROGRAM"
fi

echo "[DONE] Build/extract/freeze complete. Frozen base bitcode: $FREEZE_DIR"


