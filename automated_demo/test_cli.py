#!/usr/bin/env python3
"""
CLI testing script for EVP Pipeline integration

Usage:
    python3 test_cli.py validate                    # Validate setup
    python3 test_cli.py test-single <program>       # Test single program
    python3 test_cli.py test-batch [category]       # Test batch processing
    python3 test_cli.py check-results <program>     # Check results
"""

import sys
import json
from pathlib import Path
from evp_pipeline import EVPPipeline
from klee_runner import KLEERunner

def validate_setup():
    """Validate the integration setup"""
    print("🔍 Validating EVP Pipeline integration...")
    
    issues = []
    
    # Check config file
    config_file = Path("config/programs.json")
    if not config_file.exists():
        issues.append("Config file not found")
    else:
        print("✅ Config file found")
    
    # Check KLEE binary
    klee_bin = Path("/home/roxana/klee-env/klee-source/klee/build/bin/klee")
    if not klee_bin.exists():
        issues.append("KLEE binary not found")
    else:
        print("✅ KLEE binary found")
    
    # Test initialization
    try:
        pipeline = EVPPipeline("config/programs.json")
        print("✅ Pipeline initialized successfully")
    except Exception as e:
        issues.append(f"Pipeline initialization failed: {e}")
    
    if issues:
        print("❌ Issues found:")
        for issue in issues:
            print(f"  - {issue}")
        return False
    else:
        print("✅ All validation checks passed!")
        return True

def test_single_program(program):
    """Test a single program"""
    print(f"🧪 Testing single program: {program}")
    
    try:
        pipeline = EVPPipeline("config/programs.json")
        
        # Check if program exists in config
        if program not in pipeline.config["coreutils"]["programs"]:
            print(f"❌ Program '{program}' not found in coreutils programs")
            return False
        
        print(f"✅ Program '{program}' found in configuration")
        
        # Check if we have required files
        prog_dir = pipeline.artifacts_dir / "coreutils" / program
        bitcode_file = prog_dir / f"{program}.base.bc"
        map_file = prog_dir / "limitedValuedMap.json"
        
        if not bitcode_file.exists():
            print(f"⚠️  Bitcode file not found: {bitcode_file}")
            print("   Run Phase 1 (instrumentation) first")
            return False
        
        if not map_file.exists():
            print(f"⚠️  Map file not found: {map_file}")
            print("   Run Phase 2 (profiling) first")
            return False
        
        print("✅ Required files found")
        
        # Run Phase 3
        print(f"🚀 Running Phase 3 evaluation for {program}...")
        results = pipeline.phase3_evaluate("coreutils", program, prog_dir, map_file)
        
        print("✅ Phase 3 completed successfully!")
        return True
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return False

def test_batch_processing(category="coreutils"):
    """Test batch processing"""
    print(f"🧪 Testing batch processing for category: {category}")
    
    try:
        pipeline = EVPPipeline("config/programs.json")
        
        if category not in pipeline.config:
            print(f"❌ Category '{category}' not found in configuration")
            return False
        
        print(f"✅ Category '{category}' found")
        print(f"   Programs: {pipeline.config[category]['programs']}")
        
        # Run batch processing
        print(f"🚀 Running batch processing for {category}...")
        results = pipeline.run_batch([category])
        
        # Display results
        success_count = sum(1 for r in results if r["status"] == "success")
        total_count = len(results)
        
        print(f"✅ Batch processing completed!")
        print(f"   Results: {success_count}/{total_count} programs processed successfully")
        
        return True
        
    except Exception as e:
        print(f"❌ Batch test failed: {e}")
        return False

def check_results(program):
    """Check results for a specific program"""
    print(f"🔍 Checking results for program: {program}")
    
    try:
        pipeline = EVPPipeline("config/programs.json")
        prog_dir = pipeline.artifacts_dir / "coreutils" / program
        
        if not prog_dir.exists():
            print(f"❌ Program directory not found: {prog_dir}")
            return False
        
        print(f"✅ Program directory found: {prog_dir}")
        
        # Check for KLEE output directories
        vanilla_dirs = list(prog_dir.glob("klee-vanilla-out-*"))
        evp_dirs = list(prog_dir.glob("klee-evp-out-*"))
        
        print(f"   Vanilla KLEE runs: {len(vanilla_dirs)}")
        print(f"   EVP KLEE runs: {len(evp_dirs)}")
        
        # Check for test cases
        total_ktests = 0
        for dir_path in vanilla_dirs + evp_dirs:
            ktests = list(dir_path.glob("test*.ktest"))
            total_ktests += len(ktests)
            print(f"   {dir_path.name}: {len(ktests)} test cases")
        
        print(f"   Total test cases: {total_ktests}")
        
        # Check for results files
        results_files = list(prog_dir.glob("klee_results_*.json"))
        print(f"   Results files: {len(results_files)}")
        
        if results_files:
            latest_results = max(results_files, key=lambda p: p.stat().st_mtime)
            print(f"   Latest results: {latest_results}")
            
            # Display summary
            with open(latest_results) as f:
                results = json.load(f)
            
            vanilla = results["vanilla"]
            evp = results["evp"]
            
            print(f"\n📊 Results Summary:")
            print(f"   Vanilla KLEE: {'SUCCESS' if vanilla['success'] else 'FAILED'}")
            print(f"     - Test cases: {vanilla['ktest_count']}")
            print(f"     - Exit code: {vanilla['exit_code']}")
            
            print(f"   EVP KLEE: {'SUCCESS' if evp['success'] else 'FAILED'}")
            print(f"     - Test cases: {evp['ktest_count']}")
            print(f"     - Exit code: {evp['exit_code']}")
        
        return True
        
    except Exception as e:
        print(f"❌ Results check failed: {e}")
        return False

def main():
    """Main CLI function"""
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 test_cli.py validate")
        print("  python3 test_cli.py test-single <program>")
        print("  python3 test_cli.py test-batch [category]")
        print("  python3 test_cli.py check-results <program>")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "validate":
        success = validate_setup()
    elif command == "test-single":
        if len(sys.argv) < 3:
            print("❌ Please specify a program name")
            sys.exit(1)
        program = sys.argv[2]
        success = test_single_program(program)
    elif command == "test-batch":
        category = sys.argv[2] if len(sys.argv) > 2 else "coreutils"
        success = test_batch_processing(category)
    elif command == "check-results":
        if len(sys.argv) < 3:
            print("❌ Please specify a program name")
            sys.exit(1)
        program = sys.argv[2]
        success = check_results(program)
    else:
        print(f"❌ Unknown command: {command}")
        sys.exit(1)
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
