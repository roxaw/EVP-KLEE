#!/bin/bash
# Setup .bashrc for EVP-KLEE environment

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_status "Setting up .bashrc for EVP-KLEE environment..."

# Check if .env sourcing is already in .bashrc
if ! grep -q "source .env" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# EVP-KLEE Environment" >> ~/.bashrc
    echo "if [ -f ~/.env ]; then" >> ~/.bashrc
    echo "    source ~/.env" >> ~/.bashrc
    echo "fi" >> ~/.bashrc
    print_success "Added .env sourcing to .bashrc"
else
    print_status ".env sourcing already configured in .bashrc"
fi

# Add KLEE-specific aliases
if ! grep -q "alias klee=" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# KLEE Aliases" >> ~/.bashrc
    echo "alias klee='$KLEE_BUILD/bin/klee'" >> ~/.bashrc
    echo "alias klee-test='python3 test_environment.py'" >> ~/.bashrc
    echo "alias klee-build='bash scripts/build_klee.sh'" >> ~/.bashrc
    echo "alias klee-verify='bash scripts/verify_environment.sh'" >> ~/.bashrc
    print_success "Added KLEE aliases to .bashrc"
else
    print_status "KLEE aliases already configured in .bashrc"
fi

# Set custom PS1 for EVP-KLEE environment
if ! grep -q "EVP-KLEE" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# EVP-KLEE Prompt" >> ~/.bashrc
    echo 'export PS1="\[\033[01;32m\]EVP-KLEE\[\033[00m\]:\w\$ "' >> ~/.bashrc
    print_success "Added EVP-KLEE prompt to .bashrc"
else
    print_status "EVP-KLEE prompt already configured in .bashrc"
fi

print_success "Bash configuration completed!"
print_status "Run 'source ~/.bashrc' or restart your terminal to apply changes."
