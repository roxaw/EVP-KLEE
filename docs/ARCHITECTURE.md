# EVP-KLEE Architecture

This document describes the architecture and design of the EVP-KLEE symbolic execution pipeline.

## Overview

EVP-KLEE (Enhanced Value Profiling for KLEE) is a three-phase pipeline that enhances KLEE with value profiling capabilities to improve symbolic execution performance and coverage.

## System Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Phase 1:      │    │   Phase 2:      │    │   Phase 3:      │
│ Instrumentation │───▶│   Profiling     │───▶│  Evaluation     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Bitcode        │    │  Value Profiles │    │  KLEE Results   │
│  Extraction     │    │  Collection     │    │  Comparison     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Components

### 1. Phase 1: Instrumentation

**Purpose**: Extract LLVM bitcode and instrument programs with VASE pass

**Input**: Source programs (C/C++)
**Output**: Instrumented bitcode files (`.evpinst.bc`)

**Process**:
1. Extract bitcode from source programs
2. Apply VASE instrumentation pass
3. Link with logger and runtime libraries
4. Generate final executable

**Key Files**:
- `evp_pipeline.py` - Main pipeline controller
- `phase1_instrument()` - Instrumentation logic
- VASE pass and logger libraries

### 2. Phase 2: Profiling

**Purpose**: Run tests and collect value profiles

**Input**: Instrumented executables
**Output**: Value profile maps (`limitedValueMap.json`)

**Process**:
1. Execute instrumented programs with test inputs
2. Collect value occurrence data
3. Generate value profile maps
4. Apply filtering thresholds

**Key Files**:
- `phase2_profile()` - Profiling logic
- `generate_limited_map.py` - Map generation
- Test harness scripts

### 3. Phase 3: Evaluation

**Purpose**: Run KLEE with and without EVP enhancements

**Input**: Original bitcode and value profiles
**Output**: KLEE execution results and statistics

**Process**:
1. Run vanilla KLEE on original bitcode
2. Run EVP-enhanced KLEE with value profiles
3. Compare execution statistics
4. Generate performance reports

**Key Files**:
- `phase3_evaluate()` - Evaluation logic
- KLEE execution scripts
- Statistics comparison tools

## Data Flow

### Input Data

1. **Source Programs**: C/C++ source code
2. **Configuration**: JSON files defining programs and parameters
3. **Test Inputs**: Test cases for profiling

### Intermediate Data

1. **Bitcode Files**: LLVM IR representation
2. **Instrumented Code**: Code with VASE instrumentation
3. **Value Logs**: Raw value occurrence data
4. **Profile Maps**: Processed value profiles

### Output Data

1. **KLEE Results**: Symbolic execution outputs
2. **Statistics**: Performance metrics and comparisons
3. **Reports**: Analysis and visualization data

## File Structure

```
EVP-KLEE/
├── automated_demo/           # Main pipeline code
│   ├── evp_pipeline.py      # Pipeline controller
│   ├── config/              # Configuration files
│   ├── drivers/             # Driver programs
│   └── logs/                # Execution logs
├── klee/                    # KLEE source code
├── benchmarks/              # Test programs
├── scripts/                 # Setup and utility scripts
├── experiments/             # Experiment configurations
├── docs/                    # Documentation
├── results/                 # Analysis results
└── build/                   # Build artifacts
```

## Configuration System

### Program Configuration

Programs are defined in JSON configuration files:

```json
{
  "category": {
    "type": "cli|library",
    "programs": ["program1", "program2"],
    "thresholds": {
      "min_occurrence": 3,
      "max_values": 5
    },
    "build_cmd": "make program",
    "test_cmd": "./program --test"
  }
}
```

### Environment Configuration

Environment variables control system behavior:

```bash
LLVM_VERSION=10
CLANG_VERSION=10
KLEE_VERSION=2.3
KLEE_SRC=/workspaces/evp-klee-artifact
KLEE_BUILD=/workspaces/evp-klee-artifact/build
```

## Dependencies

### System Dependencies

- **Ubuntu 20.04**: Base operating system
- **LLVM 10**: Compiler infrastructure
- **Clang 10**: C/C++ compiler
- **CMake**: Build system
- **Git**: Version control

### Solver Dependencies

- **STP**: SMT solver for KLEE
- **Z3**: Alternative SMT solver
- **uClibc**: C library for KLEE

### Python Dependencies

- **Python 3.8+**: Runtime environment
- **wllvm**: Whole-program LLVM
- **pytest**: Testing framework
- **numpy/pandas**: Data analysis

## Execution Model

### Sequential Execution

The pipeline runs phases sequentially:

1. **Phase 1**: Process all programs in category
2. **Phase 2**: Profile all instrumented programs
3. **Phase 3**: Evaluate all programs with KLEE

### Parallel Execution

Within each phase, programs can be processed in parallel:

```python
# Example parallel processing
with ThreadPoolExecutor(max_workers=4) as executor:
    futures = [executor.submit(process_program, prog) for prog in programs]
    results = [future.result() for future in futures]
```

### Error Handling

- **Graceful degradation**: Continue processing other programs if one fails
- **Detailed logging**: Record all errors and warnings
- **Recovery mechanisms**: Retry failed operations

## Performance Considerations

### Memory Management

- **Streaming processing**: Process large datasets in chunks
- **Memory limits**: Set limits for KLEE execution
- **Cleanup**: Remove temporary files after processing

### I/O Optimization

- **Parallel I/O**: Read/write files in parallel
- **Caching**: Cache frequently accessed data
- **Compression**: Compress large output files

### Scalability

- **Batch processing**: Process multiple programs together
- **Resource monitoring**: Track CPU and memory usage
- **Load balancing**: Distribute work across available resources

## Security Considerations

### Input Validation

- **Configuration validation**: Verify JSON configuration files
- **Path sanitization**: Prevent directory traversal attacks
- **Command injection**: Sanitize command-line arguments

### Sandboxing

- **Isolated execution**: Run KLEE in controlled environment
- **Resource limits**: Limit CPU and memory usage
- **File system access**: Restrict file system operations

## Monitoring and Logging

### Logging Levels

- **DEBUG**: Detailed execution information
- **INFO**: General progress information
- **WARNING**: Non-fatal issues
- **ERROR**: Fatal errors

### Metrics Collection

- **Execution time**: Track phase and program execution times
- **Memory usage**: Monitor memory consumption
- **Success rates**: Track program processing success
- **Performance metrics**: Collect KLEE performance data

## Testing Strategy

### Unit Tests

- **Individual functions**: Test each pipeline phase
- **Mock objects**: Use mocks for external dependencies
- **Edge cases**: Test boundary conditions

### Integration Tests

- **End-to-end**: Test complete pipeline execution
- **Real programs**: Test with actual benchmark programs
- **Performance**: Verify performance requirements

### Regression Tests

- **Automated testing**: Run tests on every commit
- **Performance baselines**: Track performance over time
- **Compatibility**: Test with different environments

## Future Enhancements

### Planned Features

1. **Distributed execution**: Run pipeline across multiple machines
2. **Web interface**: Browser-based configuration and monitoring
3. **Advanced analytics**: Machine learning for value prediction
4. **Plugin system**: Extensible architecture for custom passes

### Scalability Improvements

1. **Container support**: Docker/Kubernetes deployment
2. **Cloud integration**: AWS/Azure support
3. **Database backend**: Store results in database
4. **API interface**: REST API for external integration

## Troubleshooting

### Common Issues

1. **Build failures**: Missing dependencies or configuration errors
2. **Memory issues**: Insufficient RAM or memory leaks
3. **Performance problems**: Slow execution or timeouts
4. **Data corruption**: Invalid input or output files

### Debug Tools

1. **Environment verification**: Check system configuration
2. **Log analysis**: Parse and analyze execution logs
3. **Performance profiling**: Profile execution bottlenecks
4. **Memory debugging**: Track memory usage and leaks

## Conclusion

The EVP-KLEE architecture provides a robust, scalable framework for enhancing KLEE with value profiling capabilities. The three-phase design allows for modular development and testing, while the comprehensive configuration system enables flexible experimentation with different programs and parameters.
