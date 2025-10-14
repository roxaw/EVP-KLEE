# EVP Pipeline Testing Guide

This guide provides comprehensive instructions for testing and validating the new KLEERunner-based Phase 3 functionality.

## 🚀 **Quick Start Testing**

### **Step 1: Validate Setup**
```bash
cd /home/roxana/VASE-klee/EVP-KLEE/automated_demo
python3 validate_integration.py
```

This will check:
- ✅ Config file exists and is valid
- ✅ KLEE binary is accessible
- ✅ Logger file exists
- ✅ Test environment file exists
- ✅ KLEERunner can be initialized
- ✅ EVPPipeline can be initialized

### **Step 2: Test Single Utility**
```bash
# Test with a simple utility like 'ls'
python3 -c "
from evp_pipeline import EVPPipeline
pipeline = EVPPipeline('config/programs.json')
print('Pipeline initialized successfully!')
print('Available coreutils programs:', pipeline.config['coreutils']['programs'])
"
```

## 🧪 **Testing Methods**

### **Method 1: Direct Pipeline Execution (Recommended)**

```bash
cd /home/roxana/VASE-klee/EVP-KLEE/automated_demo

# Test single utility (requires bitcode and map files from previous phases)
python3 evp_pipeline.py coreutils

# Or test specific utility if you have the artifacts
python3 -c "
from evp_pipeline import EVPPipeline
pipeline = EVPPipeline('config/programs.json')
# This will run all phases for coreutils
results = pipeline.run_batch(['coreutils'])
"
```

### **Method 2: Phase-by-Phase Testing**

```bash
python3 -c "
from evp_pipeline import EVPPipeline
pipeline = EVPPipeline('config/programs.json')

# Phase 1: Instrumentation
prog_dir = pipeline.phase1_instrument('coreutils', 'ls')
print(f'Phase 1 completed: {prog_dir}')

# Phase 2: Profiling  
map_file = pipeline.phase2_profile('coreutils', 'ls', prog_dir)
print(f'Phase 2 completed: {map_file}')

# Phase 3: KLEE Evaluation
results = pipeline.phase3_evaluate('coreutils', 'ls', prog_dir, map_file)
print(f'Phase 3 completed: {results}')
"
```

### **Method 3: KLEERunner Direct Testing**

```bash
python3 -c "
from klee_runner import KLEERunner
from pathlib import Path
import json

# Load config
with open('config/programs.json') as f:
    config = json.load(f)

# Initialize KLEERunner
klee_runner = KLEERunner(
    '/home/roxana/klee-env/klee-source/klee/build/bin/klee',
    Path('/home/roxana/VASE-klee/EVP-KLEE'),
    config
)

# Test symbolic input configuration
print('Symbolic inputs:')
for prog in ['ls', 'cp', 'du', 'grep']:
    print(f'  {prog}: {klee_runner.get_symbolic_input(prog, \"coreutils\")}')
"
```

## 🔍 **Verification Checklist**

### **1. Check Output Directories**
After running Phase 3, verify these directories exist:

```bash
# Check for KLEE output directories
ls -la /home/roxana/VASE-klee/EVP-KLEE/benchmarks/evp_artifacts/coreutils/*/klee-*-out-*

# Example structure:
# coreutils/
# ├── ls/
# │   ├── klee-vanilla-out-20241201-143022/
# │   │   ├── info
# │   │   ├── test000001.ktest
# │   │   ├── test000002.ktest
# │   │   └── ...
# │   ├── klee-evp-out-20241201-143022/
# │   │   ├── info
# │   │   ├── test000001.ktest
# │   │   └── ...
# │   └── klee_results_20241201-143022.json
```

### **2. Check Generated Files**

#### **KLEE Test Cases (.ktest files)**
```bash
# Count test cases generated
find /home/roxana/VASE-klee/EVP-KLEE/benchmarks/evp_artifacts -name "*.ktest" | wc -l

# List test cases for a specific utility
ls -la /home/roxana/VASE-klee/EVP-KLEE/benchmarks/evp_artifacts/coreutils/ls/klee-*-out-*/test*.ktest
```

#### **KLEE Info Files**
```bash
# Check KLEE statistics
cat /home/roxana/VASE-klee/EVP-KLEE/benchmarks/evp_artifacts/coreutils/ls/klee-vanilla-out-*/info
cat /home/roxana/VASE-klee/EVP-KLEE/benchmarks/evp_artifacts/coreutils/ls/klee-evp-out-*/info
```

#### **JSON Results Files**
```bash
# Check detailed results
cat /home/roxana/VASE-klee/EVP-KLEE/benchmarks/evp_artifacts/coreutils/ls/klee_results_*.json
```

### **3. Verify Both Runs Executed**

Look for these indicators in the output:

```
[PHASE 3] Running parallel KLEE evaluation for ls
[RUN] Vanilla KLEE on ls
[RUN] EVP KLEE on ls
[OK] Vanilla KLEE completed; generated 45 ktests
[OK] EVP KLEE completed; generated 38 ktests

[RESULTS] ls:
  Vanilla KLEE: SUCCESS
    - Exit code: 0
    - Test cases: 45
    - Output dir: /path/to/klee-vanilla-out-20241201-143022
  EVP KLEE: SUCCESS
    - Exit code: 0
    - Test cases: 38
    - Output dir: /path/to/klee-evp-out-20241201-143022
  QueryTime: 15.23% improvement (vanilla: 45.2s, evp: 38.3s)
```

## ⚙️ **Adding New Utilities**

### **Adding 'head' to programs.json**

```json
{
  "coreutils": {
    "programs": ["cp", "chmod", "dd", "df", "du", "grep", "head", "ln", "ls", "mkdir", "mv", "rm", "rmdir", "split", "touch"],
    "klee_config": {
      "symbolic_inputs": {
        "head": "--sym-args 0 4 8 --sym-files 1 32"
      }
    }
  }
}
```

### **Adding 'mkdir' to programs.json**

```json
{
  "coreutils": {
    "programs": ["cp", "chmod", "dd", "df", "du", "grep", "head", "ln", "ls", "mkdir", "mv", "rm", "rmdir", "split", "touch"],
    "klee_config": {
      "symbolic_inputs": {
        "mkdir": "--sym-args 1 2 8"
      }
    }
  }
}
```

### **Minimum Required Entries**

For any new utility, you need:

1. **Add to programs list**: `"programs": [..., "new_utility"]`
2. **Add symbolic input**: `"symbolic_inputs": {"new_utility": "--sym-args ..."}`

## 🧩 **Custom KLEE Flags**

### **Utility-Specific Flags**

Add to `programs.json`:

```json
{
  "coreutils": {
    "klee_config": {
      "symbolic_inputs": {
        "tail": "--sym-args 0 6 12 --sym-stdin 4096 --sym-files 3 4096 -- A B C"
      },
      "utility_specific_flags": {
        "tail": {
          "max_time": 900,
          "max_memory": 500,
          "extra_klee_flags": ["--max-solver-time=15s"]
        }
      }
    }
  }
}
```

### **Category-Wide Flags**

```json
{
  "coreutils": {
    "klee_config": {
      "max_time": 1800,
      "max_memory": 1000,
      "max_solver_time": 30,
      "extra_klee_flags": ["--watchdog", "--max-memory-inhibit=false"]
    }
  }
}
```

## 🐞 **Troubleshooting**

### **Common Issues & Solutions**

#### **1. Missing Bitcode Files**
```
❌ Bitcode not found at /path/to/program.base.bc
```
**Solution**: Run Phase 1 (instrumentation) first:
```bash
python3 -c "
from evp_pipeline import EVPPipeline
pipeline = EVPPipeline('config/programs.json')
pipeline.phase1_instrument('coreutils', 'ls')
"
```

#### **2. Missing Map Files**
```
❌ VASE map not found at /path/to/limitedValuedMap.json
```
**Solution**: Run Phase 2 (profiling) first:
```bash
python3 -c "
from evp_pipeline import EVPPipeline
pipeline = EVPPipeline('config/programs.json')
prog_dir = pipeline.phase1_instrument('coreutils', 'ls')
pipeline.phase2_profile('coreutils', 'ls', prog_dir)
"
```

#### **3. KLEE Binary Not Found**
```
❌ KLEE binary not found: /path/to/klee
```
**Solution**: Set KLEE_BIN environment variable:
```bash
export KLEE_BIN=/path/to/your/klee/binary
python3 evp_pipeline.py coreutils
```

#### **4. Permission Issues**
```
❌ Permission denied: /path/to/output
```
**Solution**: Check write permissions:
```bash
chmod -R 755 /home/roxana/VASE-klee/EVP-KLEE/benchmarks/evp_artifacts/
```

### **Log Locations**

#### **Pipeline Logs**
- **Console output**: Real-time execution logs
- **JSON results**: `evp_artifacts/coreutils/{program}/klee_results_*.json`

#### **KLEE Logs**
- **Vanilla KLEE**: `evp_artifacts/coreutils/{program}/klee-vanilla-out-*/`
- **EVP KLEE**: `evp_artifacts/coreutils/{program}/klee-evp-out-*/`

#### **Debug Information**
```bash
# Enable verbose logging
export VASE_LOG_LEVEL=DEBUG
export KLEE_VERBOSE=1

# Run with debug output
python3 evp_pipeline.py coreutils 2>&1 | tee debug.log
```

### **Pre-Execution Validation**

Run this before full execution:

```bash
# 1. Validate setup
python3 validate_integration.py

# 2. Test single utility
python3 -c "
from evp_pipeline import EVPPipeline
pipeline = EVPPipeline('config/programs.json')
# Test with a simple utility
results = pipeline.run_batch(['coreutils'])
print('Test completed successfully!')
"

# 3. Check output
ls -la /home/roxana/VASE-klee/EVP-KLEE/benchmarks/evp_artifacts/
```

## 🎯 **Recommended Testing Flow**

### **Phase 1: Basic Validation**
```bash
cd /home/roxana/VASE-klee/EVP-KLEE/automated_demo
python3 validate_integration.py
```

### **Phase 2: Single Utility Test**
```bash
# Test with 'ls' (simple utility)
python3 -c "
from evp_pipeline import EVPPipeline
pipeline = EVPPipeline('config/programs.json')
results = pipeline.run_batch(['coreutils'])
"
```

### **Phase 3: Verify Results**
```bash
# Check output directories
ls -la /home/roxana/VASE-klee/EVP-KLEE/benchmarks/evp_artifacts/coreutils/*/klee-*-out-*

# Check test cases
find /home/roxana/VASE-klee/EVP-KLEE/benchmarks/evp_artifacts -name "*.ktest" | wc -l

# Check results
cat /home/roxana/VASE-klee/EVP-KLEE/benchmarks/evp_artifacts/coreutils/ls/klee_results_*.json
```

### **Phase 4: Full Pipeline Test**
```bash
# Run all coreutils programs
python3 evp_pipeline.py coreutils
```

This testing approach ensures you can safely validate the integration before moving on to more complex benchmarks!
