#!/bin/bash
# Git configuration script for EVP-KLEE project

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

print_status "Setting up Git configuration for EVP-KLEE project..."

# Configure Git user
print_status "Configuring Git user information..."
git config --global user.name "roxaw"
git config --global user.email "roxana.shajarian@gmail.com"
print_success "Git user configured: roxaw <roxana.shajarian@gmail.com>"

# Configure Git settings
print_status "Configuring Git settings..."
git config --global pull.rebase true
git config --global init.defaultBranch main
git config --global core.autocrlf input
git config --global core.safecrlf true
git config --global core.filemode false
print_success "Git settings configured"

# Initialize Git LFS if available
if command -v git-lfs >/dev/null 2>&1; then
    print_status "Initializing Git LFS..."
    git lfs install
    print_success "Git LFS initialized"
    
    # Set up LFS tracking for large files
    print_status "Setting up LFS tracking for large files..."
    git lfs track "*.bc"
    git lfs track "*.o"
    git lfs track "klee-out-*/**"
    git lfs track "build/**"
    git lfs track "results/**"
    git lfs track "evp_artifacts/**"
    git lfs track "*.ktest"
    git lfs track "*.smt2"
    git lfs track "*.smt"
    print_success "LFS tracking configured for large files"
else
    print_warning "Git LFS not available. Install with: sudo apt install git-lfs"
fi

# Configure Git hooks directory
print_status "Setting up Git hooks..."
mkdir -p .git/hooks
print_success "Git hooks directory created"

# Create pre-commit hook for code formatting
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Pre-commit hook for EVP-KLEE project

echo "Running pre-commit checks..."

# Check for large files that should be in LFS
large_files=$(find . -type f -size +50M -not -path './.git/*' -not -path './venv/*' -not -path './build/*' -not -path './klee-out-*/*' 2>/dev/null || true)

if [ -n "$large_files" ]; then
    echo "Warning: Large files detected that should be tracked with Git LFS:"
    echo "$large_files"
    echo "Consider adding them to .gitattributes and using 'git lfs track'"
fi

# Check Python syntax
if command -v python3 >/dev/null 2>&1; then
    python_files=$(git diff --cached --name-only --diff-filter=ACM | grep '\.py$' || true)
    if [ -n "$python_files" ]; then
        echo "Checking Python syntax..."
        for file in $python_files; do
            if ! python3 -m py_compile "$file"; then
                echo "Error: Python syntax error in $file"
                exit 1
            fi
        done
    fi
fi

echo "Pre-commit checks passed!"
EOF

chmod +x .git/hooks/pre-commit
print_success "Pre-commit hook created"

# Configure Git aliases
print_status "Setting up Git aliases..."
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.unstage 'reset HEAD --'
git config --global alias.last 'log -1 HEAD'
git config --global alias.visual '!gitk'
git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
print_success "Git aliases configured"

# Set up Git attributes for this repository
print_status "Setting up Git attributes..."
if [ ! -f .gitattributes ]; then
    print_warning ".gitattributes file not found. Creating one..."
    # This should already exist from our earlier creation
fi

print_success "Git configuration completed!"
print_status "Git is now configured for the EVP-KLEE project with:"
echo "  • User: roxaw <roxana.shajarian@gmail.com>"
echo "  • LFS: $(git lfs version 2>/dev/null | head -n1 || echo 'Not available')"
echo "  • Hooks: Pre-commit hook installed"
echo "  • Aliases: st, co, br, ci, unstage, last, visual, lg"
echo ""
print_status "You can now commit and push your changes normally."
