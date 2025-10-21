#!/bin/bash
# Verify EVP-KLEE environment setup

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

# Function to check environment variable
check_env_var() {
    local var_name="$1"
    local expected_value="$2"
    
    if [ -n "${!var_name:-}" ]; then
        if [ "${!var_name}" = "$expected_value" ]; then
            print_success "$var_name: ${!var_name}"
            return 0
        else
            print_warning "$var_name: ${!var_name} (expected: $expected_value)"
            return 1
        fi
    else
        print_error "$var_name: Not set"
        return 1
    fi
}

print_status "Verifying EVP-KLEE environment setup..."
echo "=========================================="

# Initialize counters
total_checks=0
passed_checks=0

# Check system tools
print_status "Checking system tools..."

tools=(
    "git:git --version"
    "cmake:cmake --version"
    "make:make --version"
    "python3:python3 --version"
    "pip3:pip3 --version"
)

for tool_info in "${tools[@]}"; do
    tool=$(echo "$tool_info" | cut -d: -f1)
    version_cmd=$(echo "$tool_info" | cut -d: -f2)
    
    total_checks=$((total_checks + 1))
    version=$(get_version "$tool" "$version_cmd")
    
    if [ "$version" != "Not installed" ]; then
        print_success "$tool: $version"
        passed_checks=$((passed_checks + 1))
    else
        print_error "$tool: Not installed"
    fi
done

# Check LLVM and Clang
print_status "Checking LLVM and Clang..."

llvm_version=$(get_version "llvm-config-10" "llvm-config-10 --version")
total_checks=$((total_checks + 1))
if [[ "$llvm_version" == *"10."* ]]; then
    print_success "LLVM 10: $llvm_version"
    passed_checks=$((passed_checks + 1))
else
    print_error "LLVM 10: $llvm_version (expected 10.x)"
fi

clang_version=$(get_version "clang-10" "clang-10 --version")
total_checks=$((total_checks + 1))
if [[ "$clang_version" == *"10."* ]]; then
    print_success "Clang 10: $clang_version"
    passed_checks=$((passed_checks + 1))
else
    print_error "Clang 10: $clang_version (expected 10.x)"
fi

# Check solvers
print_status "Checking solvers..."

stp_version=$(get_version "stp" "stp --version")
total_checks=$((total_checks + 1))
if [ "$stp_version" != "Not installed" ]; then
    print_success "STP: $stp_version"
    passed_checks=$((passed_checks + 1))
else
    print_error "STP: Not installed"
fi

z3_version=$(get_version "z3" "z3 --version")
total_checks=$((total_checks + 1))
if [ "$z3_version" != "Not installed" ]; then
    print_success "Z3: $z3_version"
    passed_checks=$((passed_checks + 1))
else
    print_error "Z3: Not installed"
fi

# Check wllvm
wllvm_version=$(get_version "wllvm" "wllvm --version")
total_checks=$((total_checks + 1))
if [ "$wllvm_version" != "Not installed" ]; then
    print_success "wllvm: $wllvm_version"
    passed_checks=$((passed_checks + 1))
else
    print_error "wllvm: Not installed"
fi

# Check KLEE
print_status "Checking KLEE..."

klee_version=$(get_version "klee" "klee --version")
total_checks=$((total_checks + 1))
if [ "$klee_version" != "Not installed" ]; then
    if [[ "$klee_version" == *"2.3"* ]]; then
        print_success "KLEE 2.3: $klee_version"
        passed_checks=$((passed_checks + 1))
    else
        print_warning "KLEE: $klee_version (expected 2.3.x)"
    fi
else
    print_error "KLEE: Not installed (run 'bash scripts/build_klee.sh' to build it)"
fi

# Check environment variables
print_status "Checking environment variables..."

env_vars=(
    "LLVM_VERSION:10"
    "CLANG_VERSION:10"
    "KLEE_VERSION:2.3"
)

for env_info in "${env_vars[@]}"; do
    var_name=$(echo "$env_info" | cut -d: -f1)
    expected_value=$(echo "$env_info" | cut -d: -f2)
    
    total_checks=$((total_checks + 1))
    if check_env_var "$var_name" "$expected_value"; then
        passed_checks=$((passed_checks + 1))
    fi
done

# Check paths
print_status "Checking paths..."

total_checks=$((total_checks + 1))
if [ -d "${KLEE_SRC:-}" ]; then
    print_success "KLEE_SRC: $KLEE_SRC (exists)"
    passed_checks=$((passed_checks + 1))
else
    print_error "KLEE_SRC: Not set or directory doesn't exist"
fi

total_checks=$((total_checks + 1))
if [ -d "${KLEE_BUILD:-}" ]; then
    print_success "KLEE_BUILD: $KLEE_BUILD (exists)"
    passed_checks=$((passed_checks + 1))
else
    print_error "KLEE_BUILD: Not set or directory doesn't exist"
fi

# Check Python virtual environment
print_status "Checking Python environment..."

total_checks=$((total_checks + 1))
if [ -d "venv" ]; then
    print_success "Python virtual environment: venv/ (exists)"
    passed_checks=$((passed_checks + 1))
else
    print_warning "Python virtual environment: Not found (run startup script to create)"
fi

# Check if we can import required Python modules
print_status "Checking Python modules..."

python_modules=("json" "os" "subprocess" "pathlib" "datetime")

for module in "${python_modules[@]}"; do
    total_checks=$((total_checks + 1))
    if python3 -c "import $module" 2>/dev/null; then
        print_success "Python module $module: Available"
        passed_checks=$((passed_checks + 1))
    else
        print_error "Python module $module: Not available"
    fi
done

# Check directory structure
print_status "Checking directory structure..."

required_dirs=("klee" "benchmarks" "scripts" "experiments" "docs" "results" "build" "automated_demo")

for dir in "${required_dirs[@]}"; do
    total_checks=$((total_checks + 1))
    if [ -d "$dir" ]; then
        print_success "Directory $dir: Exists"
        passed_checks=$((passed_checks + 1))
    else
        print_error "Directory $dir: Missing"
    fi
done

# Check Git configuration
print_status "Checking Git configuration..."

total_checks=$((total_checks + 1))
if git config --global user.name >/dev/null 2>&1; then
    git_user=$(git config --global user.name)
    print_success "Git user: $git_user"
    passed_checks=$((passed_checks + 1))
else
    print_warning "Git user: Not configured"
fi

total_checks=$((total_checks + 1))
if git config --global user.email >/dev/null 2>&1; then
    git_email=$(git config --global user.email)
    print_success "Git email: $git_email"
    passed_checks=$((passed_checks + 1))
else
    print_warning "Git email: Not configured"
fi

# Summary
echo "=========================================="
print_status "Environment verification complete!"
echo ""

if [ $passed_checks -eq $total_checks ]; then
    print_success "All $total_checks checks passed! 🎉"
    echo ""
    print_status "Your EVP-KLEE environment is ready to use!"
    print_status "You can now:"
    echo "  • Run the EVP pipeline: python3 automated_demo/evp_pipeline.py"
    echo "  • Build KLEE: bash scripts/build_klee.sh"
    echo "  • Run tests: python3 test_environment.py"
    exit 0
else
    failed_checks=$((total_checks - passed_checks))
    print_error "$failed_checks out of $total_checks checks failed"
    echo ""
    print_status "Please fix the issues above and run this script again."
    print_status "Common solutions:"
    echo "  • Run startup script: bash scripts/startup_evp_klee.sh"
    echo "  • Build KLEE: bash scripts/build_klee.sh"
    echo "  • Setup Git: bash scripts/setup_git.sh"
    exit 1
fi
