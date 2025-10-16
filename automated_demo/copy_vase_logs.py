#!/usr/bin/env python3
"""
Copy vase_value_log.txt files to the correct artifacts directory structure
"""

import os
import shutil
from pathlib import Path

def main():
    print("=== Copying vase_value_log.txt files to artifacts directory ===")
    
    # Define paths
    script_dir = Path(__file__).parent
    artifacts_dir = script_dir / "benchmarks" / "evp_artifacts" / "coreutils"
    
    # Find all vase_value_log.txt files in the project
    project_root = script_dir.parent
    vase_logs = []
    
    # Search for vase_value_log.txt files
    for root, dirs, files in os.walk(project_root):
        for file in files:
            if file == "vase_value_log.txt":
                vase_logs.append(Path(root) / file)
    
    print(f"[INFO] Found {len(vase_logs)} vase_value_log.txt files")
    
    # Process each log file
    copied_count = 0
    for log_file in vase_logs:
        print(f"\n[PROCESS] {log_file}")
        
        # Try to determine the utility name from the path
        utility_name = None
        
        # Check if it's in a utility-specific directory
        for part in log_file.parts:
            if part in ["echo", "ls", "cp", "chmod", "mkdir", "rm", "mv", "dd", "df", "du", "ln", "split", "touch", "rmdir"]:
                utility_name = part
                break
        
        if not utility_name:
            print(f"[SKIP] Could not determine utility name for {log_file}")
            continue
        
        # Create target directory
        target_dir = artifacts_dir / utility_name
        target_dir.mkdir(parents=True, exist_ok=True)
        
        # Copy the file
        target_file = target_dir / "vase_value_log.txt"
        try:
            shutil.copy2(log_file, target_file)
            print(f"[OK] Copied to {target_file}")
            copied_count += 1
        except Exception as e:
            print(f"[ERROR] Failed to copy {log_file}: {e}")
    
    print(f"\n=== SUMMARY ===")
    print(f"Total files found: {len(vase_logs)}")
    print(f"Successfully copied: {copied_count}")
    
    # List the final structure
    print(f"\n[INFO] Current artifacts structure:")
    if artifacts_dir.exists():
        for utility_dir in sorted(artifacts_dir.iterdir()):
            if utility_dir.is_dir():
                log_file = utility_dir / "vase_value_log.txt"
                if log_file.exists():
                    size = log_file.stat().st_size
                    print(f"  {utility_dir.name}/vase_value_log.txt ({size} bytes)")
                else:
                    print(f"  {utility_dir.name}/ (no vase_value_log.txt)")

if __name__ == "__main__":
    main()
