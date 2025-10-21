# EVP-KLEE: Enhanced Value Profiling for KLEE

EVP-KLEE is an automated symbolic execution pipeline that enhances KLEE with value profiling capabilities for improved performance and coverage analysis.

- **Ubuntu 20.04** base environment
- **LLVM 10** and **Clang 10** with debug support
- **KLEE v2.3** with uClibc and POSIX runtime
- **STP** and **Z3** solvers
- **Python 3** with virtual environment
- **wllvm** for whole-program LLVM bitcode extraction
- **Complete development tools** (VS Code extensions, Git LFS, etc.)

## Google Colab Integration

For cloud-based development without local disk space constraints:

1. **Upload to Google Drive**: Use the provided upload script
2. **Open in Colab**: Upload `colab_integration/evp_colab_demo.ipynb`
3. **Run the demo**: Execute the complete EVP-KLEE pipeline in the cloud


## Project Structure

```
EVP-KLEE/
├── klee/                 # KLEE v2.3 source code
├── benchmarks/           # Test programs and benchmarks
│   ├── coreutils/        # Coreutils benchmarks
│   ├── busybox/          # BusyBox benchmarks
│   ├── apr/              # APR benchmarks
│   ├── m4/               # M4 benchmarks
│   └── custom/           # Custom benchmarks
├── scripts/              # Setup and automation scripts
├── experiments/          # Experiment configurations and results
├── docs/                 # Project documentation
├── results/              # Analysis results and statistics
├── build/                # KLEE build output
├── automated_demo/       # EVP pipeline demo scripts
│   ├── config/           # Configuration files
│   ├── drivers/          # Driver programs
│   └── logs/             # Log files
└── colab_integration/    # Google Colab integration
    ├── evp_colab_demo.ipynb
    ├── upload_to_drive.py
    └── cursor_integration_guide.md
```

## Setup environment

### Prerequisites

- Ubuntu 20.04 or compatible Linux distribution
- Git, CMake, build-essential
- Python 3.8+

## Configuration

The EVP pipeline uses JSON configuration files to define programs and their properties:

```json
{
  "coreutils": {
    "type": "cli",
    "programs": ["cp", "chmod", "dd", "df", "du", "ln", "ls", "mkdir", "mv", "rm"],
    "thresholds": {"min_occurrence": 3, "max_values": 5}
  }
}
```

## Features

- **Automated Instrumentation**: Phase 1 integration with VASE pass
- **Batch Processing**: Process multiple programs efficiently
- **Value Profiling**: Enhanced value analysis for KLEE
- **Comprehensive Logging**: Detailed execution logs and statistics
- **Validation Framework**: Automated testing and validation
- **Artifact Management**: Organized output structure
- **Cloud Integration**: Google Colab support for cloud development

## Technical Details

### Dependencies
- **LLVM 10**: Bitcode generation and manipulation
- **Clang 10**: Compilation and linking
- **KLEE v2.3**: Symbolic execution engine
- **WLLVM**: Whole-program LLVM compilation
- **EVP Pass**: Custom instrumentation pass
- **STP & Z3**: SMT solvers
