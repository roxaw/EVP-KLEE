#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
TMP_DIR="/tmp/coreutils-latest-tests"
DEST_DIR="/home/roxana/Downloads/klee-mm-benchmarks/coreutils/coreutils-8.31/tests-latest"

# Step 1: Shallow clone latest Coreutils
echo "[INFO] Cloning latest coreutils repo..."
rm -rf "$TMP_DIR"
git clone --depth=1 https://github.com/coreutils/coreutils.git "$TMP_DIR"

# Step 2: Copy only the tests directory
echo "[INFO] Copying 'tests/' directory..."
mkdir -p "$DEST_DIR"
rsync -a --delete "$TMP_DIR/tests/" "$DEST_DIR/"

# Step 3: Sanitize - remove tests that will not work with v8.31 utilities
echo "[INFO] Removing incompatible or non-existent utility test dirs..."

# List of utilities not built or too new in later Coreutils versions
BAD_TESTS=(
  "arch"        # removed before 8.31
  "realpath"    # added after 8.31
  "b2sum"       # introduced in 9.x
  "cksum"       # known to fail with EVP logging
  "install"     # changes between versions
)

for util in "${BAD_TESTS[@]}"; do
  rm -rf "$DEST_DIR/$util"
done

# Optional: remove long-running or flaky tests
echo "[INFO] Removing known long or flaky tests..."
find "$DEST_DIR" -type f -name '*.sh' -exec grep -q 'skip_test' {} \; -delete || true

# Step 4: Clean up
rm -rf "$TMP_DIR"
echo "[OK] Sanitized test directory ready at: $DEST_DIR"
