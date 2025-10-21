# EVP-KLEE Usage Guide

This guide explains how to use the EVP-KLEE symbolic execution pipeline.

## Overview

EVP-KLEE is an automated pipeline that enhances KLEE with value profiling capabilities. It consists of three main phases:

1. **Phase 1 (Instrumentation)**: Extract bitcode and instrument programs
2. **Phase 2 (Profiling)**: Run tests and collect value profiles
3. **Phase 3 (Evaluation)**: Run KLEE with and without EVP enhancements

## Quick Start

### Basic Usage

```bash
cd automated_demo
python3 evp_pipeline.py
```

This will process the default configuration (coreutils) and generate results in the `evp_artifacts/` directory.

### Processing Specific Categories

```bash
# Process only coreutils
python3 evp_pipeline.py coreutils

# Process multiple categories
python3 evp_pipeline.py coreutils apr m4
```

### Using Custom Configuration

```bash
python3 evp_pipeline.py --config config/custom_programs.json
```

## Configuration

### Program Configuration

Programs are defined in JSON configuration files. The default configuration is in `config/programs.json`:

```json
{
  "coreutils": {
    "type": "cli",
    "programs": ["cp", "chmod", "dd", "df", "du", "ln", "ls", "mkdir", "mv", "rm"],
    "thresholds": {"min_occurrence": 3, "max_values": 5}
  },
  "apr": {
    "type": "library",
    "programs": ["apr-1"],
    "thresholds": {"min_occurrence": 5, "max_values": 10}
  }
}
```

### Configuration Parameters

- **type**: Program type (`cli` for command-line tools, `library` for libraries)
- **programs**: List of programs to process
- **thresholds**: Value profiling thresholds
  - `min_occurrence`: Minimum number of occurrences for a value to be considered
  - `max_values`: Maximum number of values to track per variable

## Pipeline Phases

### Phase 1: Instrumentation

This phase extracts LLVM bitcode and instruments programs with VASE pass:

```bash
# Run only Phase 1
python3 evp_pipeline.py --phase 1

# Process specific program
python3 evp_pipeline.py --phase 1 --program cp
```

**Output**: Instrumented bitcode files (`.evpinst.bc`)

### Phase 2: Profiling

This phase runs tests and collects value profiles:

```bash
# Run only Phase 2
python3 evp_pipeline.py --phase 2

# Process specific program
python3 evp_pipeline.py --phase 2 --program cp
```

**Output**: Value profile maps (`limitedValueMap.json`)

### Phase 3: Evaluation

This phase runs KLEE with and without EVP enhancements:

```bash
# Run only Phase 3
python3 evp_pipeline.py --phase 3

# Process specific program
python3 evp_pipeline.py --phase 3 --program cp
```

**Output**: KLEE execution results and comparison statistics

## Command Line Options

```bash
python3 evp_pipeline.py [options] [categories...]

Options:
  --config FILE          Use custom configuration file
  --phase N              Run only specific phase (1, 2, or 3)
  --program NAME         Process only specific program
  --output-dir DIR       Specify output directory
  --verbose              Enable verbose output
  --help                 Show help message
```

## Output Structure

The pipeline generates results in the following structure:

```
evp_artifacts/
├── coreutils/
│   ├── cp/
│   │   ├── cp.base.bc              # Original bitcode
│   │   ├── cp.evpinst.bc           # Instrumented bitcode
│   │   ├── cp_final_exe            # Final executable
│   │   ├── limitedValueMap.json    # Value profile map
│   │   ├── klee-out-vanilla/       # Vanilla KLEE results
│   │   └── klee-out-evp/           # EVP KLEE results
│   └── ...
└── ...
```

## Monitoring and Logging

### Log Files

All execution logs are stored in `automated_demo/logs/`:

```bash
# View recent logs
ls -la logs/

# Monitor live execution
tail -f logs/evp_coreutils_$(date +%Y%m%d_%H%M%S).log
```

### Progress Monitoring

The pipeline provides progress indicators for long-running operations:

```bash
# Enable verbose output
python3 evp_pipeline.py --verbose
```

## Advanced Usage

### Custom Test Suites

Create custom test configurations:

```json
{
  "custom": {
    "type": "cli",
    "programs": ["my_program"],
    "thresholds": {"min_occurrence": 2, "max_values": 3},
    "test_cmd": "./my_program --test",
    "build_cmd": "make my_program"
  }
}
```

### Batch Processing

Process multiple programs in parallel:

```bash
# Process all categories
python3 evp_pipeline.py coreutils apr m4

# Process with custom output directory
python3 evp_pipeline.py --output-dir /path/to/results coreutils
```

### Integration with CI/CD

The pipeline can be integrated into CI/CD workflows:

```yaml
# Example GitHub Actions workflow
- name: Run EVP Pipeline
  run: |
    cd automated_demo
    python3 evp_pipeline.py coreutils
    python3 test_environment.py
```

## Performance Tuning

### Memory Optimization

For large programs, adjust memory settings:

```bash
# Set memory limit for KLEE
export KLEE_MEMORY_LIMIT=8192  # 8GB in MB

# Run pipeline
python3 evp_pipeline.py
```

### Parallel Processing

Process multiple programs in parallel:

```bash
# Set number of parallel jobs
export EVP_PARALLEL_JOBS=4

# Run pipeline
python3 evp_pipeline.py
```

## Troubleshooting

### Common Issues

1. **Out of memory**: Reduce `max_values` in configuration
2. **Build failures**: Check that all dependencies are installed
3. **KLEE timeouts**: Increase timeout values in configuration
4. **Permission errors**: Ensure scripts are executable

### Debug Mode

Enable debug output for troubleshooting:

```bash
# Enable debug logging
export EVP_DEBUG=1
python3 evp_pipeline.py --verbose
```

### Validation

Validate the environment and results:

```bash
# Check environment
bash scripts/verify_environment.sh

# Validate results
python3 check_artifacts_structure.py
```

## Examples

### Example 1: Process Coreutils

```bash
cd automated_demo
python3 evp_pipeline.py coreutils
```

### Example 2: Custom Configuration

```bash
# Create custom config
cat > config/my_programs.json << EOF
{
  "my_tools": {
    "type": "cli",
    "programs": ["tool1", "tool2"],
    "thresholds": {"min_occurrence": 2, "max_values": 5}
  }
}
EOF

# Run with custom config
python3 evp_pipeline.py --config config/my_programs.json my_tools
```

### Example 3: Single Program Analysis

```bash
# Process only 'ls' from coreutils
python3 evp_pipeline.py --program ls coreutils
```

## Best Practices

1. **Start small**: Begin with a few programs to test the setup
2. **Monitor resources**: Watch memory and disk usage during execution
3. **Use version control**: Commit configuration changes
4. **Document results**: Keep notes on interesting findings
5. **Regular cleanup**: Remove old artifacts to save space

## Getting Help

- Check `docs/TROUBLESHOOTING.md` for common issues
- Run `bash scripts/verify_environment.sh` for environment diagnostics
- Review logs in `automated_demo/logs/` for execution details
- See `docs/ARCHITECTURE.md` for system architecture details
