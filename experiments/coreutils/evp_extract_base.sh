#!/bin/bash

# Script to extract base bitcode for all utilities and store checksums

# Exit on any error
set -e

# Directory setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COREUTILS_DIR="$SCRIPT_DIR/coreutils-8.31"
LLVM_OBJ_DIR="$COREUTILS_DIR/obj-llvm"
UTILS_LIST="$SCRIPT_DIR/target_utils.txt"
OUTPUT_DIR="$SCRIPT_DIR/evp_artifacts"

# Logging setup
LOG_FILE="$OUTPUT_DIR/extraction.log"
mkdir -p "$OUTPUT_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling function
handle_error() {
    log "ERROR: An error occurred while processing $CURRENT_UTIL"
    log "Command failed: $BASH_COMMAND"
    log "Error on line $1"
    exit 1
}

# Set up error handling
trap 'handle_error $LINENO' ERR

# Initialize log
echo "=== Base Bitcode Extraction Started $(date) ===" > "$LOG_FILE"

# Verify we're in a built state
if [ ! -d "$LLVM_OBJ_DIR" ]; then
    log "Error: obj-llvm directory not found. Please ensure coreutils is built with WLLVM first."
    exit 1
fi

# Process each utility
while read -r util; do
    if [ -z "$util" ]; then
        continue
    fi
    
    CURRENT_UTIL=$util
    log "Processing $util..."
    
    # Create utility-specific directory
    UTIL_DIR="$OUTPUT_DIR/$util"
    mkdir -p "$UTIL_DIR"
    
    # Check if utility exists
    if [ ! -f "$LLVM_OBJ_DIR/src/$util" ]; then
        log "Error: $util not found in obj-llvm/src. Skipping."
        continue
    fi
    
    cd "$LLVM_OBJ_DIR/src"
    
    # Extract base bitcode
    log "Extracting base bitcode for $util..."
    extract-bc -o "${util}.base.bc" "./$util"
    
    # Verify extraction succeeded
    if [ ! -f "${util}.base.bc" ]; then
        log "Error: Failed to extract bitcode for $util"
        continue
    fi
    
    # Store checksum and copy base bitcode
    log "Storing checksum and copying base bitcode..."
    sha256sum "${util}.base.bc" | tee "$UTIL_DIR/${util}.base.bc.sha256"
    cp "${util}.base.bc" "$UTIL_DIR/"
    
    # Verify the copy
    if sha256sum -c "$UTIL_DIR/${util}.base.bc.sha256" >/dev/null 2>&1; then
        log "Successfully processed $util"
    else
        log "Error: Checksum verification failed for $util"
        exit 1
    fi
done < "$UTILS_LIST"

log "Base bitcode extraction completed for all utilities"
echo "=== Base Bitcode Extraction Completed $(date) ===" >> "$LOG_FILE"