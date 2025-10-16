#!/usr/bin/env python3
"""
Check the current structure of the evp_artifacts directory
"""

from pathlib import Path

def main():
    print("=== EVP Artifacts Directory Structure ===")
    
    artifacts_dir = Path(__file__).parent / "benchmarks" / "evp_artifacts" / "coreutils"
    
    if not artifacts_dir.exists():
        print(f"[ERROR] Artifacts directory not found: {artifacts_dir}")
        return
    
    print(f"[INFO] Artifacts directory: {artifacts_dir}")
    print()
    
    utilities = []
    for item in sorted(artifacts_dir.iterdir()):
        if item.is_dir():
            utilities.append(item.name)
    
    if not utilities:
        print("[INFO] No utility directories found")
        return
    
    print(f"[INFO] Found {len(utilities)} utility directories:")
    print()
    
    for utility in utilities:
        utility_dir = artifacts_dir / utility
        print(f"📁 {utility}/")
        
        # List files in the utility directory
        files = list(utility_dir.iterdir())
        if not files:
            print("   (empty)")
        else:
            for file in sorted(files):
                if file.is_file():
                    size = file.stat().st_size
                    if file.name == "vase_value_log.txt":
                        print(f"   📄 {file.name} ({size} bytes) ⭐")
                    else:
                        print(f"   📄 {file.name} ({size} bytes)")
                elif file.is_dir():
                    print(f"   📁 {file.name}/")
        print()

if __name__ == "__main__":
    main()
