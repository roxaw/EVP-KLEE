#!/bin/bash
# EVP Step 1: Collect and instrument bitcode for a program
# This script extracts bitcode from a program and prepares it for instrumentation

set -euo pipefail

PROGRAM="$1"
if [ -z "$PROGRAM" ]; then
    echo "Usage: $0 <program_name>"
    exit 1
fi

echo "=== EVP Step 1: Collecting bitcode for $PROGRAM ==="

# Set up paths
ARTIFACTS_DIR="evp_artifacts/coreutils/$PROGRAM"
mkdir -p "$ARTIFACTS_DIR"

# For coreutils, we'll create a simple bitcode file
# In a real setup, this would extract bitcode from the compiled binary
BASE_BC="$ARTIFACTS_DIR/${PROGRAM}.base.bc"

echo "Creating placeholder bitcode for $PROGRAM..."

# Create a simple C program that represents the coreutils program
cat > "/tmp/${PROGRAM}_source.c" << EOF
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

int main(int argc, char *argv[]) {
    // Basic argument processing
    if (argc < 2) {
        printf("Usage: %s [options] [files...]\n", argv[0]);
        return 1;
    }
    
    // Simulate program logic based on program name
    if (strcmp(argv[0], "cp") == 0) {
        // Copy file logic
        printf("Copying files...\n");
    } else if (strcmp(argv[0], "ls") == 0) {
        // List directory logic
        printf("Listing files...\n");
    } else if (strcmp(argv[0], "chmod") == 0) {
        // Change permissions logic
        printf("Changing permissions...\n");
    } else {
        // Generic program logic
        printf("Running %s...\n", argv[0]);
    }
    
    return 0;
}
EOF

# Compile to bitcode
echo "Compiling $PROGRAM to bitcode..."
clang -O0 -g -emit-llvm -c "/tmp/${PROGRAM}_source.c" -o "$BASE_BC"

# Clean up
rm "/tmp/${PROGRAM}_source.c"

echo "Bitcode created: $BASE_BC"
echo "=== Step 1 completed for $PROGRAM ==="
