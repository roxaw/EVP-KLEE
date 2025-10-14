# EVP Pipeline Integration Guide

This guide explains how the `step3_generic.sh` script has been integrated into the EVP automated pipeline, providing comprehensive KLEE execution capabilities with utility-specific symbolic input configurations.

## Overview

The integration brings the following key features from `step3_generic.sh` into the Python pipeline:

1. **Parallel KLEE Execution**: Both vanilla and EVP-enabled KLEE runs execute in parallel
2. **Utility-Specific Symbolic Inputs**: Each coreutils utility has tailored symbolic input configurations
3. **Comprehensive KLEE Flags**: All the advanced KLEE flags from the original script
4. **Sandbox Management**: Automatic creation and cleanup of test sandboxes
5. **Detailed Results**: Enhanced result comparison and reporting

## Architecture

### New Components

#### 1. KLEERunner Class (`klee_runner.py`)

The `KLEERunner` class encapsulates all KLEE execution logic:

```python
from klee_runner import KLEERunner

# Initialize with KLEE binary and project root
klee_runner = KLEERunner(klee_bin, project_root, config)

# Run parallel evaluation
results = klee_runner.run_parallel_evaluation(
    bitcode_path=bitcode_file,
    map_file=vase_map_file,
    program="ls",
    category="coreutils",
    run_id="test_run",
    extra_args=[],
    test_env=test_env_file
)
```

**Key Features:**
- **Symbolic Input Configuration**: Built-in configurations for 100+ coreutils utilities
- **Config File Integration**: Uses `programs.json` for utility-specific settings
- **Parallel Execution**: Runs vanilla and EVP KLEE simultaneously
- **Sandbox Management**: Creates isolated test environments
- **Result Parsing**: Extracts and compares KLEE statistics

#### 2. Enhanced Configuration Schema

The `programs.json` config now includes KLEE-specific settings:

```json
{
  "coreutils": {
    "type": "cli",
    "programs": ["ls", "cp", "du", ...],
    "klee_config": {
      "max_time": 1800,
      "max_memory": 1000,
      "max_solver_time": 30,
      "test_env": "test.env",
      "extra_klee_flags": [],
      "symbolic_inputs": {
        "ls": "--sym-args 0 2 8 --sym-files 1 32",
        "cp": "--sym-args 2 2 8 --sym-files 2 32",
        "du": "--sym-args 0 1 8 --sym-files 1 32"
      }
    }
  }
}
```

#### 3. Enhanced Phase 3 Evaluation

The `phase3_evaluate` method now provides:

- **Parallel KLEE Execution**: Both vanilla and EVP runs
- **Configuration-Driven**: Uses settings from `programs.json`
- **Comprehensive Logging**: Detailed execution logs
- **Result Comparison**: Performance metrics comparison
- **JSON Results**: Structured result storage

## Usage Examples

### 1. Single Program Evaluation

```python
from evp_pipeline import EVPPipeline

# Initialize pipeline
pipeline = EVPPipeline("config/programs.json")

# Run evaluation for a specific program
prog_dir = pipeline.artifacts_dir / "coreutils" / "ls"
map_file = prog_dir / "limitedValuedMap.json"
bitcode_file = prog_dir / "ls.base.bc"

results = pipeline.phase3_evaluate("coreutils", "ls", prog_dir, map_file)
```

### 2. Batch Processing

```python
# Run all coreutils programs
results = pipeline.run_batch(["coreutils"])

# Run specific programs
pipeline.run_batch(["coreutils"])  # All coreutils
pipeline.run_batch(["apr", "m4"])  # Specific categories
```

### 3. Custom Symbolic Inputs

To add custom symbolic input configurations:

```json
{
  "coreutils": {
    "klee_config": {
      "symbolic_inputs": {
        "my_utility": "--sym-args 0 3 10 --sym-files 2 64 A B"
      }
    }
  }
}
```

## Symbolic Input Configurations

The integration includes comprehensive symbolic input configurations for coreutils utilities:

### File Operations
- **ls**: `--sym-args 0 2 8 --sym-files 1 32` (directory listings, options)
- **cp**: `--sym-args 2 2 8 --sym-files 2 32` (src + dst + file contents)
- **mv**: `--sym-args 2 2 8 --sym-files 2 16` (src + dst + small files)
- **rm**: `--sym-args 1 2 8 --sym-files 1 16` (target files)

### Text Processing
- **grep**: `--sym-args 0 4 8 --sym-files 2 32 A B` (patterns + files)
- **sort**: `--sym-args 0 4 8 --sym-stdin 2048 --sym-files 2 4096 A B` (file lines + sort flags)
- **wc**: `--sym-args 0 6 10 --sym-stdin 4096 --sym-files 3 4096 A B C` (word count options)

### System Utilities
- **chmod**: `--sym-args 2 2 8 --sym-files 1 16` (mode + target file)
- **mkdir**: `--sym-args 1 2 8` (directory names)
- **dd**: `--sym-args 0 6 12 --sym-files 2 32 A B` (data conversion options)

## KLEE Flags Configuration

The integration uses the same comprehensive KLEE flags as `step3_generic.sh`:

```python
klee_flags_base = [
    "--libc=uclibc", "--posix-runtime", "--simplify-sym-indices",
    "--write-cvcs", "--write-cov", "--stats", "--write-smt2s",
    "--output-module", "--max-memory=1000", "--disable-inlining",
    "--optimize", "--use-forked-solver", "--use-cex-cache",
    "--external-calls=all", "--only-output-states-covering-new",
    "--max-sym-array-size=4096", "--max-solver-time=30s",
    "--max-time=1800s", "--watchdog", "--max-memory-inhibit=false",
    "--max-static-fork-pct=1", "--max-static-solve-pct=1",
    "--max-static-cpfork-pct=1", "--switch-type=internal",
    "--search=random-path", "--search=nurs:covnew",
    "--use-batching-search", "--batch-instructions=10000"
]
```

## Result Analysis

The integration provides comprehensive result analysis:

### Performance Metrics
- **QueryTime**: Time spent on constraint solving
- **SolverTime**: Time spent in SMT solvers
- **WallTime**: Total execution time
- **NumQueries**: Number of constraint queries
- **NumStates**: Number of symbolic states explored
- **NumInstructions**: Number of instructions executed

### Comparison Display
```
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
  SolverTime: 12.45% improvement (vanilla: 32.1s, evp: 28.1s)
  WallTime: 8.67% improvement (vanilla: 180.5s, evp: 164.8s)
```

## Testing

Use the provided test script to verify the integration:

```bash
cd automated_demo
python3 test_integration.py
```

The test script will:
1. Test single program evaluation
2. Test batch processing
3. Display comprehensive results
4. Verify all components work correctly

## Migration from step3_generic.sh

To migrate from the standalone `step3_generic.sh` script:

1. **Replace direct script calls** with pipeline methods
2. **Move symbolic input configurations** to `programs.json`
3. **Use the KLEERunner class** for custom KLEE execution
4. **Leverage the enhanced result analysis** for better insights

## Benefits of Integration

1. **Unified Workflow**: All EVP phases in one pipeline
2. **Configuration Management**: Centralized settings in JSON
3. **Enhanced Logging**: Comprehensive execution logs
4. **Result Persistence**: Structured JSON result storage
5. **Parallel Execution**: Efficient resource utilization
6. **Extensibility**: Easy to add new utilities and configurations

## Troubleshooting

### Common Issues

1. **Missing Bitcode Files**: Run Phase 1 (instrumentation) first
2. **Missing Map Files**: Run Phase 2 (profiling) first
3. **KLEE Binary Not Found**: Set `KLEE_BIN` environment variable
4. **Permission Issues**: Ensure write access to output directories

### Debug Mode

Enable verbose logging by setting environment variables:

```bash
export VASE_LOG_LEVEL=DEBUG
export KLEE_VERBOSE=1
```

This integration provides a robust, scalable solution for running comprehensive KLEE evaluations as part of the EVP pipeline, with all the functionality of the original `step3_generic.sh` script plus enhanced configuration management and result analysis.
