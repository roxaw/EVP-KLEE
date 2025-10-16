# EVP-KLEE: Enhanced Value Profiling with KLEE

A comprehensive pipeline for automated value profiling and symbolic execution analysis of coreutils utilities using KLEE.

## 🎯 Overview

This project implements an Enhanced Value Profiling (EVP) pipeline that combines value profiling with KLEE symbolic execution to analyze coreutils utilities. The pipeline consists of three main phases:

1. **Phase 1 (Instrumentation)**: Extract bitcode, instrument with VASE pass, and build executables
2. **Phase 2 (Profiling)**: Run tests and collect value information
3. **Phase 3 (Evaluation)**: Perform symbolic execution with KLEE

## ✅ Current Status

- ✅ **Phase 1 Complete**: Full instrumentation pipeline with batch processing
- 🔄 **Phase 2 In Progress**: Profiling and value collection
- 🔄 **Phase 3 Planned**: KLEE symbolic execution integration

## 🚀 Quick Start

### Prerequisites

- LLVM 10
- Clang 10
- KLEE v2.3
- WLLVM
- Python 3.6+
- Coreutils 8.31

### Installation

1. Clone the repository:
```bash
git clone https://github.com/YOUR_USERNAME/EVP-KLEE.git
cd EVP-KLEE
```

2. Build coreutils with LLVM support:
```bash
cd benchmarks/coreutils-8.31
./configure CC=wllvm CFLAGS="-g"
make
cd obj-llvm/src
extract-bc -o utility.bc ./utility
```

3. Run Phase 1 (Instrumentation):
```bash
cd automated_demo
python3 test_phase1_small_batch.py  # Test with 3 utilities
python3 run_phase1_batch.py         # Process all utilities
```

## 📁 Project Structure

```
EVP-KLEE/
├── automated_demo/                 # Main pipeline directory
│   ├── benchmarks/
│   │   └── evp_artifacts/         # Generated artifacts
│   │       └── coreutils/         # Per-utility artifacts
│   ├── tools/
│   │   ├── vasepass/              # VASE instrumentation pass
│   │   └── logger/                # Logger runtime
│   ├── config/
│   │   └── programs.json          # Utility configurations
│   ├── evp_pipeline.py            # Main pipeline
│   ├── test_phase1_small_batch.py # Small batch testing
│   ├── run_phase1_batch.py        # Full batch processing
│   └── [management scripts...]
├── benchmarks/
│   └── coreutils-8.31/            # Coreutils source and build
└── experiments/                    # Experimental scripts
```

## 🔧 Usage

### Phase 1: Instrumentation

```bash
# Test with small batch (echo, ls, cp)
python3 test_phase1_small_batch.py

# Process all coreutils utilities
python3 run_phase1_batch.py

# Check artifacts structure
python3 check_artifacts_structure.py
```

### Individual Utility Processing

```bash
# Process single utility
python3 evp_pipeline.py --phase1 echo

# Run complete pipeline for single utility
python3 evp_pipeline.py --all echo
```

## 📊 Features

### Phase 1 (Instrumentation)
- **Automated Bitcode Extraction**: Extract LLVM bitcode from coreutils binaries
- **VASE Instrumentation**: Apply VASE pass for value profiling
- **Logger Integration**: Build and link logger runtime
- **Library Support**: Full ACL and attribute library support
- **Batch Processing**: Process multiple utilities automatically
- **Validation**: Comprehensive validation at each step

### Management Tools
- **Log Management**: Copy and organize vase_value_log.txt files
- **Structure Validation**: Check artifacts directory structure
- **Error Handling**: Detailed error reporting and recovery
- **Progress Tracking**: Real-time progress monitoring

## 🛠️ Technical Details

### Dependencies
- **LLVM 10**: Bitcode generation and manipulation
- **Clang 10**: Compilation and linking
- **KLEE v2.3**: Symbolic execution engine
- **WLLVM**: Whole-program LLVM compilation
- **VASE Pass**: Custom instrumentation pass

### Supported Utilities
- echo, ls, cp, chmod, mkdir, rm, mv, dd, df, du, ln, split, touch, rmdir

### Artifacts Generated
For each utility, the pipeline generates:
- `utility.base.bc`: Original bitcode
- `utility.evpinstr.bc`: Instrumented bitcode
- `logger.bc`: Logger runtime
- `utility_final.bc`: Linked bitcode
- `utility_final_exe`: Final executable
- `vase_value_log.txt`: Value profiling data (Phase 2)

## 📈 Performance

- **Batch Processing**: Process 13+ utilities in parallel
- **Validation**: Multi-level validation at each step
- **Error Recovery**: Robust error handling and reporting
- **Memory Efficient**: Optimized for large-scale processing

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📞 Support

For questions or issues:
- Create an issue on GitHub
- Contact: [Your Contact Information]

## 🎯 Roadmap

- [ ] Phase 2 (Profiling) implementation
- [ ] Phase 3 (KLEE Evaluation) integration
- [ ] Performance optimization
- [ ] Additional utility support
- [ ] Comprehensive documentation

---

**Last Updated**: January 16, 2025  
**Version**: 1.0.0  
**Status**: Phase 1 Complete