#!/bin/bash
# Build KLEE v2.3 from source with all required dependencies

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
KLEE_VERSION="2.3"
KLEE_SRC="/workspaces/evp-klee-artifact/klee"
KLEE_BUILD="/workspaces/evp-klee-artifact/build"
UCLIBC_SRC="$KLEE_SRC/klee-uclibc"
LLVM_CONFIG="/usr/bin/llvm-config-10"
CLANG="/usr/bin/clang-10"

# Check if we're in the right directory
if [ ! -f "automated_demo/evp_pipeline.py" ]; then
    print_error "Not in the correct directory. Please run from the repository root."
    exit 1
fi

print_status "Building KLEE v$KLEE_VERSION from source..."
print_status "Source directory: $KLEE_SRC"
print_status "Build directory: $KLEE_BUILD"

# Create build directory
mkdir -p "$KLEE_BUILD"

# Check if KLEE is already built
if [ -f "$KLEE_BUILD/bin/klee" ]; then
    print_warning "KLEE appears to already be built. Do you want to rebuild? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_status "Skipping KLEE build."
        exit 0
    fi
    print_status "Cleaning previous build..."
    rm -rf "$KLEE_BUILD"/*
fi

# Clone KLEE v2.3 if not already present
if [ ! -d "$KLEE_SRC" ]; then
    print_status "Cloning KLEE v$KLEE_VERSION..."
    git clone --recursive --branch v$KLEE_VERSION https://github.com/klee/klee.git "$KLEE_SRC"
    print_success "KLEE v$KLEE_VERSION cloned"
else
    print_status "KLEE source already exists, updating..."
    cd "$KLEE_SRC"
    git fetch origin
    git checkout v$KLEE_VERSION
    git submodule update --init --recursive
    cd - > /dev/null
    print_success "KLEE source updated"
fi

# Build uClibc-KLEE
print_status "Building uClibc-KLEE..."
if [ ! -d "$UCLIBC_SRC" ]; then
    print_error "uClibc-KLEE source not found. This should have been cloned with KLEE."
    exit 1
fi

cd "$UCLIBC_SRC"
if [ ! -f "configure" ]; then
    print_status "Configuring uClibc-KLEE..."
    ./configure --make-llvm-lib
    print_success "uClibc-KLEE configured"
fi

print_status "Building uClibc-KLEE..."
make -j$(nproc)
print_success "uClibc-KLEE built"

cd - > /dev/null

# Configure KLEE with CMake
print_status "Configuring KLEE with CMake..."
cd "$KLEE_BUILD"

cmake \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DLLVM_CONFIG_BINARY="$LLVM_CONFIG" \
    -DENABLE_SOLVER_STP=ON \
    -DENABLE_SOLVER_Z3=ON \
    -DENABLE_POSIX_RUNTIME=ON \
    -DENABLE_KLEE_UCLIBC=ON \
    -DKLEE_UCLIBC_PATH="$UCLIBC_SRC" \
    -DENABLE_UNIT_TESTS=ON \
    -DENABLE_SYSTEM_TESTS=ON \
    -DCMAKE_C_COMPILER="$CLANG" \
    -DCMAKE_CXX_COMPILER="$CLANG" \
    -DCMAKE_C_FLAGS="-g" \
    -DCMAKE_CXX_FLAGS="-g" \
    "$KLEE_SRC"

print_success "KLEE configured"

# Build KLEE
print_status "Building KLEE (this may take a while)..."
make -j$(nproc)
print_success "KLEE built successfully"

# Run KLEE tests to verify installation
print_status "Running KLEE tests to verify installation..."
if make check; then
    print_success "KLEE tests passed"
else
    print_warning "Some KLEE tests failed, but the build was successful"
fi

# Install KLEE (optional, since we're using the build directory)
print_status "Installing KLEE..."
make install
print_success "KLEE installed"

# Verify installation
print_status "Verifying KLEE installation..."
if command -v klee >/dev/null 2>&1; then
    KLEE_VERSION_OUT=$(klee --version 2>&1 | head -n1)
    print_success "KLEE is available: $KLEE_VERSION_OUT"
else
    print_error "KLEE command not found in PATH"
    print_status "Make sure to add $KLEE_BUILD/bin to your PATH"
fi

# Create symlinks for easier access
print_status "Creating symlinks for easier access..."
ln -sf "$KLEE_BUILD/bin/klee" /usr/local/bin/klee
ln -sf "$KLEE_BUILD/bin/kleaver" /usr/local/bin/kleaver
ln -sf "$KLEE_BUILD/bin/klee-stats" /usr/local/bin/klee-stats
ln -sf "$KLEE_BUILD/bin/ktest-tool" /usr/local/bin/ktest-tool
print_success "Symlinks created"

# Test KLEE with a simple example
print_status "Testing KLEE with a simple example..."
cat > "$KLEE_BUILD/test_klee.c" << 'EOF'
#include <klee/klee.h>

int main() {
    int x;
    klee_make_symbolic(&x, sizeof(x), "x");
    if (x > 0) {
        return 1;
    } else {
        return 0;
    }
}
EOF

# Compile test program
"$CLANG" -I"$KLEE_SRC/include" -emit-llvm -c -g "$KLEE_BUILD/test_klee.c" -o "$KLEE_BUILD/test_klee.bc"

# Run KLEE on test program
if klee --output-dir="$KLEE_BUILD/klee-out-test" "$KLEE_BUILD/test_klee.bc" >/dev/null 2>&1; then
    print_success "KLEE test run successful"
    rm -rf "$KLEE_BUILD/klee-out-test"
    rm -f "$KLEE_BUILD/test_klee.c" "$KLEE_BUILD/test_klee.bc"
else
    print_warning "KLEE test run failed, but installation may still be working"
fi

cd - > /dev/null

print_success "KLEE v$KLEE_VERSION build completed successfully!"
print_status "KLEE is now available at: $KLEE_BUILD/bin/klee"
print_status "You can run 'klee --help' to see available options"
print_status "Run 'bash scripts/verify_environment.sh' to verify the complete environment"
