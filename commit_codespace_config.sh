#!/bin/bash
# Script to commit and push Codespace configuration files

set -euo pipefail

echo "Starting commit process for EVP-KLEE Codespace configuration..."

# Check if we're in the right directory
if [ ! -f "automated_demo/evp_pipeline.py" ]; then
    echo "Error: Not in the correct directory"
    exit 1
fi

# Check git status
echo "Checking git status..."
git status

# Add all new files
echo "Adding all Codespace configuration files..."
git add .devcontainer/
git add .gitattributes
git add requirements.txt
git add scripts/
git add docs/
git add benchmarks/
git add experiments/
git add klee/
git add .env
git add .gitignore
git add README.md

# Check what's staged
echo "Checking staged files..."
git status --cached

# Commit the changes
echo "Committing changes..."
git commit -m "Add complete EVP-KLEE Codespace configuration

- Add .devcontainer/ with Dockerfile and devcontainer.json
- Add comprehensive scripts for setup, build, and verification
- Add complete documentation (SETUP.md, USAGE.md, TROUBLESHOOTING.md, ARCHITECTURE.md)
- Add workspace directory structure (klee/, benchmarks/, experiments/, docs/, results/)
- Add Python requirements.txt with all dependencies
- Add .gitattributes for Git LFS support
- Update .gitignore for KLEE artifacts
- Update README.md with Codespace quick start guide
- Add environment configuration (.env file)

This enables GitHub Codespace with Ubuntu 20.04, LLVM 10, Clang 10, KLEE v2.3, STP, Z3, and wllvm."

# Push to remote
echo "Pushing to remote repository..."
git push origin main

echo "Successfully committed and pushed all Codespace configuration files!"

