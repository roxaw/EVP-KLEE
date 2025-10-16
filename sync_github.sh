#!/bin/bash
set -euo pipefail

echo "=== GitHub Repository Sync Script ==="

# Navigate to project directory
cd /home/roxana/VASE-klee/EVP-KLEE

echo "[STEP 1] Checking git status..."
if [ ! -d ".git" ]; then
    echo "[INFO] Initializing git repository..."
    git init
else
    echo "[INFO] Git repository already exists"
fi

echo "[STEP 2] Adding all files..."
git add .

echo "[STEP 3] Checking status..."
git status

echo "[STEP 4] Creating comprehensive commit..."
git commit -m "Complete EVP-KLEE Phase 1 Integration

Major Features Implemented:
- Integrated Phase 1 (Instrumentation) into EVP pipeline
- Added batch processing for coreutils utilities
- Standardized artifacts directory structure
- Fixed path inconsistencies and tool integration
- Added ACL library support for complex utilities
- Created comprehensive validation framework
- Implemented management and utility scripts

Technical Changes:
- evp_pipeline.py: Complete Phase 1 integration with validation
- test_phase1_small_batch.py: Small batch testing framework
- run_phase1_batch.py: Full batch processing system
- copy_vase_logs.py: Log file management utility
- check_artifacts_structure.py: Structure validation tool
- Fixed VASE pass and logger paths
- Added ACL/attribute library support
- Standardized directory structure

Status: Phase 1 Complete, Ready for Phase 2 (Profiling)"

echo "[STEP 5] Setting up remote repository..."
# Check if remote exists
if git remote get-url origin >/dev/null 2>&1; then
    echo "[INFO] Remote origin already exists"
    git remote -v
else
    echo "[INFO] Please add your GitHub repository URL:"
    echo "Run: git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
    echo "Then run: git push -u origin main"
fi

echo "[STEP 6] Pushing to GitHub..."
if git remote get-url origin >/dev/null 2>&1; then
    git push -u origin main
    echo "[SUCCESS] Repository synced to GitHub!"
else
    echo "[INFO] Please add remote repository first:"
    echo "git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
    echo "git push -u origin main"
fi

echo ""
echo "=== SYNC COMPLETE ==="
echo "Repository is ready for sharing with your mentor!"
