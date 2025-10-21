#!/bin/bash
# EVP-KLEE Codespace Startup Script
# This script verifies the environment and sets up the development workspace

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get version of a tool
get_version() {
    local tool="$1"
    local version_cmd="$2"
    
    if command_exists "$tool"; then
        $version_cmd 2>/dev/null | head -n1 || echo "Unknown"
    else
        echo "Not installed"
    fi
}

print_status "Starting EVP-KLEE Codespace setup..."

# Check if we're in the right directory
if [ ! -f "automated_demo/evp_pipeline.py" ]; then
    print_error "Not in the correct directory. Please run from the repository root."
    exit 1
fi

# Create directory structure if it doesn't exist
print_status "Creating workspace directory structure..."
mkdir -p klee benchmarks scripts experiments docs results build automated_demo/logs

# Set up environment variables
print_status "Setting up environment variables..."

# Create .env file
cat > .env << EOF
LLVM_VERSION=10
CLANG_VERSION=10
KLEE_VERSION=2.3
KLEE_SRC=/workspaces/evp-klee-artifact
KLEE_BUILD=/workspaces/evp-klee-artifact/build
SOLVERS=STP,Z3
PYTHON=python3
LLVM_COMPILER=clang
CC=wllvm
CXX=wllvm++
EOF

# Source environment variables
export LLVM_VERSION=10
export CLANG_VERSION=10
export KLEE_VERSION=2.3
export KLEE_SRC=/workspaces/evp-klee-artifact
export KLEE_BUILD=/workspaces/evp-klee-artifact/build
export LLVM_COMPILER=clang
export CC=wllvm
export CXX=wllvm++
export PATH=$KLEE_BUILD/bin:$PATH

# Update .bashrc to source .env
if ! grep -q "source .env" ~/.bashrc; then
    echo "source .env" >> ~/.bashrc
fi

# Create symlink for LLVM
if [ ! -L "llvm" ]; then
    print_status "Creating LLVM symlink..."
    ln -s /usr/lib/llvm-10 llvm
fi

# Set up Python virtual environment
print_status "Setting up Python virtual environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    print_success "Created Python virtual environment"
fi

# Activate virtual environment
source venv/bin/activate

# Install Python requirements
if [ -f "requirements.txt" ]; then
    print_status "Installing Python requirements..."
    pip install --upgrade pip
    pip install -r requirements.txt
    print_success "Installed Python requirements"
fi

# Verify tool installations
print_status "Verifying tool installations..."

# Check LLVM 10
LLVM_VERSION_OUT=$(get_version "llvm-config-10" "llvm-config-10 --version")
if [[ "$LLVM_VERSION_OUT" == *"10."* ]]; then
    print_success "LLVM 10: $LLVM_VERSION_OUT"
else
    print_error "LLVM 10 not found or incorrect version: $LLVM_VERSION_OUT"
fi

# Check Clang 10
CLANG_VERSION_OUT=$(get_version "clang-10" "clang-10 --version")
if [[ "$CLANG_VERSION_OUT" == *"10."* ]]; then
    print_success "Clang 10: $CLANG_VERSION_OUT"
else
    print_error "Clang 10 not found or incorrect version: $CLANG_VERSION_OUT"
fi

# Check STP
STP_VERSION_OUT=$(get_version "stp" "stp --version")
if [[ "$STP_VERSION_OUT" != "Not installed" ]]; then
    print_success "STP: $STP_VERSION_OUT"
else
    print_error "STP not found"
fi

# Check Z3
Z3_VERSION_OUT=$(get_version "z3" "z3 --version")
if [[ "$Z3_VERSION_OUT" != "Not installed" ]]; then
    print_success "Z3: $Z3_VERSION_OUT"
else
    print_error "Z3 not found"
fi

# Check Python
PYTHON_VERSION_OUT=$(get_version "python3" "python3 --version")
if [[ "$PYTHON_VERSION_OUT" != "Not installed" ]]; then
    print_success "Python: $PYTHON_VERSION_OUT"
else
    print_error "Python3 not found"
fi

# Check wllvm
WLLVM_VERSION_OUT=$(get_version "wllvm" "wllvm --version")
if [[ "$WLLVM_VERSION_OUT" != "Not installed" ]]; then
    print_success "wllvm: $WLLVM_VERSION_OUT"
else
    print_error "wllvm not found"
fi

# Check if KLEE is built
if [ -f "$KLEE_BUILD/bin/klee" ]; then
    KLEE_VERSION_OUT=$(get_version "klee" "klee --version")
    if [[ "$KLEE_VERSION_OUT" == *"2.3"* ]]; then
        print_success "KLEE 2.3: $KLEE_VERSION_OUT"
    else
        print_warning "KLEE found but version may be incorrect: $KLEE_VERSION_OUT"
    fi
else
    print_warning "KLEE not built yet. Run 'bash scripts/build_klee.sh' to build it."
fi

# Set up Git configuration
print_status "Setting up Git configuration..."
if ! git config --global user.name >/dev/null 2>&1; then
    git config --global user.name "roxaw"
    print_success "Set Git user.name to 'roxaw'"
fi

if ! git config --global user.email >/dev/null 2>&1; then
    git config --global user.email "roxana.shajarian@gmail.com"
    print_success "Set Git user.email to 'roxana.shajarian@gmail.com'"
fi

# Initialize Git LFS if not already done
if ! git lfs version >/dev/null 2>&1; then
    print_warning "Git LFS not available. Install it with: sudo apt install git-lfs"
else
    if ! git lfs track >/dev/null 2>&1; then
        git lfs install
        print_success "Initialized Git LFS"
    fi
fi

# Create a simple test to verify the environment
print_status "Creating environment test..."
cat > test_environment.py << 'EOF'
#!/usr/bin/env python3
"""Test script to verify EVP-KLEE environment setup"""

import subprocess
import sys
import os

def test_command(cmd, expected_in_output=None):
    """Test if a command runs and optionally check output"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            if expected_in_output and expected_in_output in result.stdout:
                print(f"✓ {cmd}")
                return True
            elif not expected_in_output:
                print(f"✓ {cmd}")
                return True
            else:
                print(f"✗ {cmd} - unexpected output")
                return False
        else:
            print(f"✗ {cmd} - failed with return code {result.returncode}")
            return False
    except Exception as e:
        print(f"✗ {cmd} - exception: {e}")
        return False

def main():
    print("Testing EVP-KLEE environment...")
    print("=" * 50)
    
    tests = [
        ("llvm-config-10 --version", "10."),
        ("clang-10 --version", "10."),
        ("python3 --version", None),
        ("wllvm --version", None),
        ("stp --version", None),
        ("z3 --version", None),
    ]
    
    passed = 0
    total = len(tests)
    
    for cmd, expected in tests:
        if test_command(cmd, expected):
            passed += 1
    
    print("=" * 50)
    print(f"Environment test: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! Environment is ready.")
        return 0
    else:
        print("❌ Some tests failed. Check the setup.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
EOF

chmod +x test_environment.py

# Run the environment test
print_status "Running environment test..."
python3 test_environment.py

# Display welcome message
echo ""
echo "=========================================="
echo "🎉 EVP-KLEE Codespace is ready!"
echo "=========================================="
echo ""
echo "Environment Details:"
echo "  • LLVM: $LLVM_VERSION_OUT"
echo "  • Clang: $CLANG_VERSION_OUT"
echo "  • STP: $STP_VERSION_OUT"
echo "  • Z3: $Z3_VERSION_OUT"
echo "  • Python: $PYTHON_VERSION_OUT"
echo "  • wllvm: $WLLVM_VERSION_OUT"
echo ""
echo "Next Steps:"
echo "  1. Build KLEE: bash scripts/build_klee.sh"
echo "  2. Run tests: python3 test_environment.py"
echo "  3. Start development: cd automated_demo && python3 evp_pipeline.py"
echo ""
echo "Useful Commands:"
echo "  • Check environment: bash scripts/verify_environment.sh"
echo "  • Build KLEE: bash scripts/build_klee.sh"
echo "  • Run EVP pipeline: python3 automated_demo/evp_pipeline.py"
echo ""
echo "Happy coding! 🚀"
echo "=========================================="
