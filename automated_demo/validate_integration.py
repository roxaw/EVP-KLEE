#!/usr/bin/env python3
"""
Validation script for KLEERunner integration

This script performs basic validation checks before running the full pipeline.
"""

import sys
import json
from pathlib import Path
from evp_pipeline import EVPPipeline
from klee_runner import KLEERunner

def check_prerequisites():
    """Check if all prerequisites are available"""
    print("🔍 Checking prerequisites...")
    
    issues = []
    
    # Check if config file exists
    config_file = Path("config/programs.json")
    if not config_file.exists():
        issues.append(f"❌ Config file not found: {config_file}")
    else:
        print(f"✅ Config file found: {config_file}")
    
    # Check if KLEE binary exists
    klee_bin = Path("/home/roxana/klee-env/klee-source/klee/build/bin/klee")
    if not klee_bin.exists():
        issues.append(f"❌ KLEE binary not found: {klee_bin}")
    else:
        print(f"✅ KLEE binary found: {klee_bin}")
    
    # Check if logger.c exists
    logger_c = Path("/home/roxana/VASE-klee/logger.c")
    if not logger_c.exists():
        issues.append(f"❌ Logger file not found: {logger_c}")
    else:
        print(f"✅ Logger file found: {logger_c}")
    
    # Check if test environment exists
    test_env = Path("../benchmarks/test.env")
    if not test_env.exists():
        issues.append(f"❌ Test environment file not found: {test_env}")
    else:
        print(f"✅ Test environment file found: {test_env}")
    
    return issues

def check_config_schema():
    """Validate the configuration schema"""
    print("\n🔍 Validating configuration schema...")
    
    try:
        with open("config/programs.json") as f:
            config = json.load(f)
        
        issues = []
        
        for category, cat_config in config.items():
            print(f"  Checking category: {category}")
            
            # Check required fields
            required_fields = ["type", "programs", "thresholds"]
            for field in required_fields:
                if field not in cat_config:
                    issues.append(f"❌ Missing field '{field}' in category '{category}'")
            
            # Check KLEE config
            if "klee_config" in cat_config:
                klee_config = cat_config["klee_config"]
                if "symbolic_inputs" not in klee_config:
                    issues.append(f"❌ Missing 'symbolic_inputs' in klee_config for '{category}'")
                else:
                    print(f"    ✅ Found {len(klee_config['symbolic_inputs'])} symbolic input configurations")
            else:
                issues.append(f"❌ Missing 'klee_config' in category '{category}'")
        
        return issues
        
    except Exception as e:
        return [f"❌ Config validation failed: {e}"]

def test_klee_runner_initialization():
    """Test KLEERunner initialization"""
    print("\n🔍 Testing KLEERunner initialization...")
    
    try:
        with open("config/programs.json") as f:
            config = json.load(f)
        
        klee_runner = KLEERunner(
            "/home/roxana/klee-env/klee-source/klee/build/bin/klee",
            Path("/home/roxana/VASE-klee/EVP-KLEE"),
            config
        )
        
        print("✅ KLEERunner initialized successfully")
        
        # Test symbolic input retrieval
        test_programs = ["ls", "cp", "du", "grep"]
        for program in test_programs:
            symbolic_input = klee_runner.get_symbolic_input(program, "coreutils")
            print(f"    ✅ {program}: {symbolic_input}")
        
        return []
        
    except Exception as e:
        return [f"❌ KLEERunner initialization failed: {e}"]

def test_pipeline_initialization():
    """Test EVPPipeline initialization"""
    print("\n🔍 Testing EVPPipeline initialization...")
    
    try:
        pipeline = EVPPipeline("config/programs.json")
        print("✅ EVPPipeline initialized successfully")
        
        # Check if artifacts directory was created
        if pipeline.artifacts_dir.exists():
            print(f"✅ Artifacts directory exists: {pipeline.artifacts_dir}")
        else:
            print(f"⚠️  Artifacts directory not created: {pipeline.artifacts_dir}")
        
        return []
        
    except Exception as e:
        return [f"❌ EVPPipeline initialization failed: {e}"]

def main():
    """Main validation function"""
    print("=" * 60)
    print("EVP Pipeline Integration Validation")
    print("=" * 60)
    
    all_issues = []
    
    # Run all checks
    all_issues.extend(check_prerequisites())
    all_issues.extend(check_config_schema())
    all_issues.extend(test_klee_runner_initialization())
    all_issues.extend(test_pipeline_initialization())
    
    print("\n" + "=" * 60)
    print("Validation Results:")
    print("=" * 60)
    
    if all_issues:
        print("❌ Issues found:")
        for issue in all_issues:
            print(f"  {issue}")
        print(f"\nTotal issues: {len(all_issues)}")
        return False
    else:
        print("✅ All validation checks passed!")
        print("\n🚀 Ready to run the pipeline!")
        return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
