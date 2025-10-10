#!/usr/bin/env bash
set -euo pipefail

# === Usage & defaults =========================================================
usage() {
  cat <<'EOF'
Usage: evp_collect_util.sh --util <name> [options]

Required:
  -u, --util NAME            Utility name (e.g., du, ls, cp, sort)

Optional:
  --coreutils-dir DIR        Path to coreutils-8.31 source tree
                             (default: auto-detect near this script)
  --artifacts-dir DIR        Where per-utility bc/logs live (default: ./evp_artifacts)
  --max-values N             Max limited values per var (default: 3)
  --min-occurrence N         Min occurrences per var/site (default: 5)
  --tests-file FILE          File listing test scripts (one per line)
  --only-collect             Run collection only (skip map generation)
  --only-map                 Run map generation only (uses existing log)
  --opt PATH                 LLVM opt (default: /usr/lib/llvm-10/bin/opt)
  --pass-so PATH             VASE pass .so (default: /home/roxana/VASE-klee/vasepass/libVaseInstrumentPass.so)
  --logger-c PATH            logger.c (not compiled here; kept for consistency)
  -h, --help                 Show this help

Notes:
- Expects <artifacts-dir>/<util>/<util>.base.bc (and optional .sha256) to exist.
- Test list:
    1) --tests-file FILE (highest precedence), or
    2) built-in case mapping, or
    3) auto-discover tests/<util>/*.sh in the coreutils tree.
EOF
}

# === Parse args ===============================================================
UTIL=""
COREUTILS_DIR_ARG=""
ARTIFACTS_DIR="./evp_artifacts"
MAX_VALUES="${MAX_VALUES:-3}"
MIN_OCCURRENCE="${MIN_OCCURRENCE:-5}"
TESTS_FILE=""
ONLY_COLLECT=0
ONLY_MAP=0

OPT_BIN="${OPT:-/usr/lib/llvm-10/bin/opt}"
PASS_SO="${PASS_SO:-/home/roxana/VASE-klee/vasepass/libVaseInstrumentPass.so}"
LOGGER_C="${LOG_C:-/home/roxana/VASE-klee/logger.c}"

while (( "$#" )); do
  case "$1" in
    -u|--util) UTIL="$2"; shift 2 ;;
    --coreutils-dir) COREUTILS_DIR_ARG="$2"; shift 2 ;;
    --artifacts-dir) ARTIFACTS_DIR="$2"; shift 2 ;;
    --max-values) MAX_VALUES="$2"; shift 2 ;;
    --min-occurrence) MIN_OCCURRENCE="$2"; shift 2 ;;
    --tests-file) TESTS_FILE="$2"; shift 2 ;;
    --only-collect) ONLY_COLLECT=1; shift ;;
    --only-map) ONLY_MAP=1; shift ;;
    --opt) OPT_BIN="$2"; shift 2 ;;
    --pass-so) PASS_SO="$2"; shift 2 ;;
    --logger-c) LOGGER_C="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1"; usage; exit 1 ;;
  esac
done

[[ -z "${UTIL}" ]] && { echo "Error: --util is required"; usage; exit 1; }

# === Directories, paths, tools ===============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Coreutils dir: explicit > sibling > parent sibling
if [[ -n "${COREUTILS_DIR_ARG}" ]]; then
  COREUTILS_DIR="${COREUTILS_DIR_ARG}"
else
  if [[ -d "$SCRIPT_DIR/coreutils-8.31" ]]; then
    COREUTILS_DIR="$SCRIPT_DIR/coreutils-8.31"
  elif [[ -d "$SCRIPT_DIR/../coreutils-8.31" ]]; then
    COREUTILS_DIR="$SCRIPT_DIR/../coreutils-8.31"
  else
    echo "Error: coreutils-8.31 not found. Use --coreutils-dir."
    exit 1
  fi
fi

UTIL_DIR="$ARTIFACTS_DIR/$UTIL"
OUT_DIR="$UTIL_DIR/test-outputs"
mkdir -p "$UTIL_DIR" "$OUT_DIR"

# EVP bitcode artifacts
BASE_BC="$UTIL_DIR/${UTIL}.base.bc"
BASE_SHA="$BASE_BC.sha256"
INSTR_BC="$UTIL_DIR/${UTIL}_instr.bc"

# EVP log + final JSON map
UTIL_DIR="$(cd "$UTIL_DIR" && pwd)"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
LOG_FILE="$UTIL_DIR/collection.log"
VASE_LOG="$UTIL_DIR/vase_value_log.txt"
MAP_JSON="$UTIL_DIR/limitedValuedMap.json"

# === Logging helpers ==========================================================
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}
header() {
  echo "=== ${UTIL^^} Value Collection Started $(date) ===" > "$LOG_FILE"
}

# === Sanity checks ============================================================
header
command -v "$OPT_BIN" >/dev/null 2>&1 || { log "Error: opt not found: $OPT_BIN"; exit 1; }
[[ -f "$PASS_SO" ]] || { log "Error: PASS_SO not found: $PASS_SO"; exit 1; }

if [[ "$ONLY_MAP" -eq 0 ]]; then
  [[ -f "$BASE_BC" ]] || { log "Error: Missing base bitcode: $BASE_BC"; exit 1; }
  if [[ -f "$BASE_SHA" ]]; then
    log "Verifying base bitcode checksum..."
    if ! (cd "$UTIL_DIR" && sha256sum -c "$(basename "$BASE_SHA")" >/dev/null 2>&1); then
      log "Error: Base bitcode verification failed for $BASE_BC"
      exit 1
    fi
  else
    log "No checksum file found for $BASE_BC (continuing without verification)"
  fi
fi

# === Instrumentation (Step 1A) ===============================================
if [[ "$ONLY_MAP" -eq 0 ]]; then
  log "Applying EVP instrumentation to $BASE_BC → $INSTR_BC ..."
  "$OPT_BIN" -load "$PASS_SO" -vase-instrument "$BASE_BC" -o "$INSTR_BC"
  log "Instrumentation complete: $INSTR_BC"

# Build runtime logger as a shared object and an instrumented executable
CLANG_BIN="${CLANG:-/usr/lib/llvm-10/bin/clang}"

LOGGER_SO="$UTIL_DIR/libvase_logger.so"
"$CLANG_BIN" -O2 -fPIC -shared "$LOGGER_C" -o "$LOGGER_SO"

INSTR_EXE="$UTIL_DIR/${UTIL}_instr"
"$CLANG_BIN" "$INSTR_BC" -o "$INSTR_EXE" -lm -ldl -lpthread -lz

# Fresh value log and stable absolute VASE_LOG
: > "$VASE_LOG"
export VASE_LOG="$VASE_LOG"
log "Set VASE_LOG=$VASE_LOG"

# Ensure tests execute our instrumented binary and can resolve __vase_log_var
export LD_PRELOAD="$LOGGER_SO"
UPPER=$(printf '%s' "$UTIL" | tr '[:lower:]' '[:upper:]')
export "$UPPER"="$INSTR_EXE"
export PATH="$UTIL_DIR:$PATH"


  # Prepare fresh value log
  : > "$VASE_LOG"
  export VASE_LOG
  log "Set VASE_LOG=$VASE_LOG"
fi

# === Enter coreutils, ensure read/exec perms =================================
if ! cd "$COREUTILS_DIR" 2>/dev/null; then
  log "Cannot access $COREUTILS_DIR; attempting to add user rwX perms"
  chmod -R u+rwX "$COREUTILS_DIR" || true
  cd "$COREUTILS_DIR" || { log "Error: Cannot access $COREUTILS_DIR after chmod"; exit 1; }
fi

# === Load testing environment, if present ====================================
if [[ -f "$SCRIPT_DIR/testing-env.sh" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/testing-env.sh"
  set +a
  log "Loaded testing-env.sh"
else
  log "Warning: testing-env.sh not found at $SCRIPT_DIR (continuing)"
fi

# === Build test list for the utility =========================================
TESTS=()

add_tests_from_file() {
  local f="$1"
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    TESTS+=("$line")
  done < "$f"
}

discover_tests_for() {
  local u="$1"
  if [[ -d "tests/$u" ]]; then
    # find prints absolute or relative paths; normalize relative to coreutils dir
    while IFS= read -r -d '' f; do
      TESTS+=("${f#./}")  # strip leading ./ if present
    done < <(find "tests/$u" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)
  fi
}

case_map_tests() {
  local u="$1"
  case "$u" in
    du)
      TESTS=(
        "tests/du/basic.sh"
        "tests/du/inodes.sh"
        "tests/du/inacc-dest.sh"
        "tests/du/inaccessible-cwd.sh"
        "tests/du/one-file-system.sh"
      )
      ;;
    ls)
      # Conservative starter set; full set will be auto-discovered if present
      TESTS=()
      ;;
    cp)
      TESTS=()
      ;;
    sort)
      TESTS=()
      ;;
    *)
      TESTS=()
      ;;
  esac
}

if [[ -n "$TESTS_FILE" ]]; then
  [[ -f "$TESTS_FILE" ]] || { log "Error: --tests-file not found: $TESTS_FILE"; exit 1; }
  add_tests_from_file "$TESTS_FILE"
else
  case_map_tests "$UTIL"
  # If case mapping empty or files missing, fall back to discovery
  if [[ ${#TESTS[@]} -eq 0 ]]; then
    discover_tests_for "$UTIL"
  fi
fi

if [[ ${#TESTS[@]} -eq 0 ]]; then
  log "Error: No tests found for utility '$UTIL'. Provide --tests-file or ensure tests/$UTIL/*.sh exist."
  exit 1
fi

# === Run tests (Step 1B) =====================================================
if [[ "$ONLY_MAP" -eq 0 ]]; then
  log "Running ${UTIL} test cases (${#TESTS[@]} found)..."
  for t in "${TESTS[@]}"; do
    # Some tests expect srcdir='.' (when they 'source tests/init.sh'), others 'tests'
    # We inspect early lines to decide, mirroring your du logic.
    SRC='tests'
    if sed -n '1,20p' "$t" | grep -q "/tests/init.sh"; then
      SRC='.'
    fi

    base="$(basename "$t")"
    out="$OUT_DIR/$base.out"
    err="$OUT_DIR/$base.err"

    log "Running test: $t (srcdir=$SRC)"
    if built_programs=" $UTIL " srcdir="$SRC" VERBOSE=yes "$t" >"$out" 2>"$err"; then
      log "PASS: $t"
    else
      st=$?
      if [[ $st -eq 77 ]]; then
        log "SKIP: $t"
      else
        log "FAIL: $t (exit $st)"
      fi
    fi
  done

  # Verify value collection
  if [[ -f "$VASE_LOG" ]]; then
    log "Value collection completed for $UTIL"
    log "Value log lines: $(wc -l < "$VASE_LOG")"
  else
    log "Error: No value log generated at $VASE_LOG"
    exit 1
  fi

  echo "=== ${UTIL^^} Value Collection Completed $(date) ===" >> "$LOG_FILE"
fi

# === Step 2: Limited value map generation ====================================
if [[ "$ONLY_COLLECT" -eq 0 ]]; then
  cd "$SCRIPT_DIR"
  log "Generating limited value map → $MAP_JSON (max=$MAX_VALUES, min=$MIN_OCCURRENCE)"

  # Your Python has CLI flags; keep that interface.
  python3 generate_limited_map.py \
    --log "$VASE_LOG" \
    --out "$MAP_JSON" \
    --max-values "$MAX_VALUES" \
    --min-occurrence "$MIN_OCCURRENCE"

  log "Map generation completed"
  echo "=== Map Generation Completed $(date) ===" >> "$LOG_FILE"
fi

log "All done for utility '$UTIL'. Artifacts in: $UTIL_DIR"
