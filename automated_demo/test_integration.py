#!/usr/bin/env python3
"""
Test script for the integrated EVP pipeline with KLEE execution

This script demonstrates how to use the enhanced pipeline with the step3_generic.sh
functionality integrated into the Python pipeline.
"""

import sys
from pathlib import Path
from evp_pipeline import EVPPipeline

def test_single_program():
    """Test the pipeline with a single coreutils program"""
    print("Testing EVP pipeline integration with single program...")
    
    # Initialize pipeline
    pipeline = EVPPipeline("config/programs.json")
    
    # Test with a simple program (assuming we have bitcode and map files)
    program = "ls"
    category = "coreutils"
    
    print(f"\nTesting {program} from {category}")
    
    # Check if we have the required files
    prog_dir = pipeline.artifacts_dir / category / program
    bitcode_file = prog_dir / f"{program}.base.bc"
    map_file = prog_dir / "limitedValuedMap.json"
    
    if not bitcode_file.exists():
        print(f"[SKIP] Bitcode file not found: {bitcode_file}")
        print("Run phase 1 (instrumentation) first to generate bitcode")
        return False
    
    if not map_file.exists():
        print(f"[SKIP] Map file not found: {map_file}")
        print("Run phase 2 (profiling) first to generate map")
        return False
    
    # Run phase 3 (KLEE evaluation)
    try:
        results = pipeline.phase3_evaluate(category, program, prog_dir, map_file)
        print(f"[SUCCESS] KLEE evaluation completed for {program}")
        return True
    except Exception as e:
        print(f"[ERROR] KLEE evaluation failed for {program}: {e}")
        return False

def test_batch_programs():
    """Test the pipeline with multiple programs"""
    print("\nTesting EVP pipeline integration with batch processing...")
    
    # Initialize pipeline
    pipeline = EVPPipeline("config/programs.json")
    
    # Test with a subset of coreutils programs
    test_programs = ["ls", "touch", "cp"]
    
    print(f"Testing programs: {test_programs}")
    
    # Run batch processing
    try:
        results = pipeline.run_batch(["coreutils"])
        print(f"[SUCCESS] Batch processing completed")
        
        # Display summary
        success_count = sum(1 for r in results if r["status"] == "success")
        total_count = len(results)
        print(f"Results: {success_count}/{total_count} programs processed successfully")
        
        return True
    except Exception as e:
        print(f"[ERROR] Batch processing failed: {e}")
        return False

def main():
    """Main test function"""
    print("=" * 60)
    print("EVP Pipeline Integration Test")
    print("=" * 60)
    
    # Test single program
    single_success = test_single_program()
    
    # Test batch processing
    batch_success = test_batch_programs()
    
    print("\n" + "=" * 60)
    print("Test Summary:")
    print(f"Single program test: {'PASSED' if single_success else 'FAILED'}")
    print(f"Batch processing test: {'PASSED' if batch_success else 'FAILED'}")
    print("=" * 60)
    
    return single_success and batch_success

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
