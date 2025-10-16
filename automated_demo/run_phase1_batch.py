#!/usr/bin/env python3
"""
Batch Phase 1 processing for coreutils utilities with validation
"""

import sys
import json
from pathlib import Path
from evp_pipeline import EVPPipeline

def main():
    print("=== EVP Phase 1 Batch Processing ===")
    
    # Load configuration
    config_file = Path(__file__).parent / "config" / "programs.json"
    if not config_file.exists():
        print(f"[ERROR] Configuration file not found: {config_file}")
        sys.exit(1)
    
    with open(config_file) as f:
        config = json.load(f)
    
    # Get coreutils utilities
    if "coreutils" not in config:
        print("[ERROR] No coreutils configuration found")
        sys.exit(1)
    
    utilities = config["coreutils"]["programs"]
    print(f"[INFO] Found {len(utilities)} coreutils utilities to process")
    print(f"[INFO] Utilities: {', '.join(utilities)}")
    
    # Initialize pipeline
    pipeline = EVPPipeline(str(config_file))
    
    # Process each utility
    successful = []
    failed = []
    
    for i, utility in enumerate(utilities, 1):
        print(f"\n{'='*60}")
        print(f"[{i}/{len(utilities)}] Processing: {utility}")
        print(f"{'='*60}")
        
        try:
            # Run Phase 1 for this utility
            prog_dir = pipeline.phase1_instrument("coreutils", utility)
            
            # Additional validation
            validate_phase1_complete(prog_dir, utility)
            
            successful.append(utility)
            print(f"[SUCCESS] {utility} Phase 1 completed successfully")
            
        except Exception as e:
            failed.append((utility, str(e)))
            print(f"[FAILED] {utility} Phase 1 failed: {e}")
            continue
    
    # Summary
    print(f"\n{'='*60}")
    print("=== BATCH PROCESSING SUMMARY ===")
    print(f"{'='*60}")
    print(f"Total utilities: {len(utilities)}")
    print(f"Successful: {len(successful)}")
    print(f"Failed: {len(failed)}")
    
    if successful:
        print(f"\n[SUCCESS] Completed utilities: {', '.join(successful)}")
    
    if failed:
        print(f"\n[FAILED] Failed utilities:")
        for utility, error in failed:
            print(f"  - {utility}: {error}")
    
    # Check if we should continue to Phase 2
    if successful and len(successful) > 0:
        print(f"\n[INFO] Ready for Phase 2 processing")
        print(f"[INFO] Run Phase 2 for individual utilities or use the full pipeline")
    
    return len(failed) == 0

def validate_phase1_complete(prog_dir, utility):
    """Additional validation for Phase 1 completion"""
    print(f"[VALIDATE] Additional validation for {utility}")
    
    # Check all required files exist and are non-empty
    required_files = [
        f"{utility}.base.bc",
        f"{utility}.base.bc.sha256",
        f"{utility}.evpinstr.bc", 
        "logger.bc",
        f"{utility}_final.bc",
        f"{utility}_final_exe"
    ]
    
    # Check for vase_value_log.txt if it exists (from Phase 2)
    vase_log = prog_dir / "vase_value_log.txt"
    if vase_log.exists():
        required_files.append("vase_value_log.txt")
    
    for file in required_files:
        file_path = prog_dir / file
        if not file_path.exists():
            raise RuntimeError(f"Missing file: {file}")
        if file_path.stat().st_size == 0:
            raise RuntimeError(f"Empty file: {file}")
    
    # Check symlink exists and points to correct location
    # The symlinks are created in the main project's benchmarks directory, not automated_demo's
    project_root = Path(__file__).parent.parent.resolve()
    cu_dir = project_root / "benchmarks" / "coreutils-8.31"
    obj_src = cu_dir / "obj-llvm" / "src"
    symlink_path = obj_src / utility
    
    if not symlink_path.exists():
        raise RuntimeError(f"Symlink not found: {symlink_path}")
    
    if not symlink_path.is_symlink():
        raise RuntimeError(f"Not a symlink: {symlink_path}")
    
    # Check symlink target exists
    target_path = symlink_path.resolve()
    if not target_path.exists():
        raise RuntimeError(f"Symlink target not found: {target_path}")
    
    print(f"[OK] All validations passed for {utility}")

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
