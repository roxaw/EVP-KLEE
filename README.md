# EVP-KLEE: Enhanced Value Profiling for KLEE

EVP-KLEE is an automated symbolic execution pipeline that enhances KLEE with value profiling capabilities for improved performance and coverage analysis.

## 🚀 Quick Start with GitHub Codespace

The easiest way to get started with EVP-KLEE is using GitHub Codespace:

1. **Open in Codespace**: Click the "Code" button and select "Codespaces" → "Create codespace on main"
2. **Wait for setup**: The Codespace will automatically build the complete environment
3. **Verify installation**: Run `bash scripts/verify_environment.sh` to check everything is working
4. **Start developing**: The environment is ready to use!

### What's Included in the Codespace

- **Ubuntu 20.04** base environment
- **LLVM 10** and **Clang 10** with debug support
- **KLEE v2.3** with uClibc and POSIX runtime
- **STP** and **Z3** solvers
- **Python 3** with virtual environment
- **wllvm** for whole-program LLVM bitcode extraction
- **Complete development tools** (VS Code extensions, Git LFS, etc.)

## 🌐 Google Colab Integration

For cloud-based development without local disk space constraints:

1. **Upload to Google Drive**: Use the provided upload script
2. **Open in Colab**: Upload `colab_integration/evp_colab_demo.ipynb`
3. **Run the demo**: Execute the complete EVP-KLEE pipeline in the cloud
4. **Cursor IDE Integration**: Download the notebook and open in Cursor for AI assistance

See `colab_integration/cursor_integration_guide.md` for detailed setup instructions.

## 📁 Project Structure

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

## 🛠️ Manual Setup (Alternative to Codespace)

If you prefer to set up the environment manually:

### Prerequisites

- Ubuntu 20.04 or compatible Linux distribution
- Git, CMake, build-essential
- Python 3.8+

### Installation Steps

1. **Clone the repository**:
   ```bash
   git clone https://github.com/roxaw/evp-klee-artifact.git
   cd evp-klee-artifact
   ```

2. **Run the setup script**:
   ```bash
   bash scripts/startup_evp_klee.sh
   ```

3. **Build KLEE** (if not using Codespace):
   ```bash
   bash scripts/build_klee.sh
   ```

4. **Verify the environment**:
   ```bash
   bash scripts/verify_environment.sh
   ```

## 🎯 Usage

### Running the EVP Pipeline

1. **Basic usage**:
   ```bash
   cd automated_demo
   python3 evp_pipeline.py
   ```

2. **Process specific category**:
   ```bash
   python3 evp_pipeline.py coreutils
   ```

3. **Run with custom configuration**:
   ```bash
   python3 evp_pipeline.py --config config/custom_programs.json
   ```

### Available Scripts

- `scripts/startup_evp_klee.sh` - Initialize the development environment
- `scripts/build_klee.sh` - Build KLEE v2.3 from source
- `scripts/verify_environment.sh` - Verify all tools are installed correctly
- `scripts/setup_git.sh` - Configure Git with LFS support
- `scripts/setup_directories.sh` - Create workspace directory structure

## 🔧 Configuration

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

## 📊 Features

- **Automated Instrumentation**: Phase 1 integration with VASE pass
- **Batch Processing**: Process multiple programs efficiently
- **Value Profiling**: Enhanced value analysis for KLEE
- **Comprehensive Logging**: Detailed execution logs and statistics
- **Validation Framework**: Automated testing and validation
- **Artifact Management**: Organized output structure
- **Cloud Integration**: Google Colab support for cloud development
- **AI Assistance**: Cursor IDE integration for enhanced development

## 🎯 Current Status

- ✅ **Phase 1 Complete**: Full instrumentation pipeline with batch processing
- ✅ **Google Colab Integration**: Cloud-based development environment
- ✅ **Documentation**: Comprehensive setup and usage guides
- 🔄 **Phase 2 In Progress**: Profiling and value collection
- 🔄 **Phase 3 Planned**: KLEE symbolic execution integration

## 🛠️ Technical Details

### Dependencies
- **LLVM 10**: Bitcode generation and manipulation
- **Clang 10**: Compilation and linking
- **KLEE v2.3**: Symbolic execution engine
- **WLLVM**: Whole-program LLVM compilation
- **VASE Pass**: Custom instrumentation pass
- **STP & Z3**: SMT solvers

### Supported Programs
- **Coreutils**: cp, chmod, dd, df, du, ln, ls, mkdir, mv, rm, rmdir, split, touch
- **BusyBox**: echo, cat, ls, mkdir, rm
- **APR**: apr_test
- **M4**: m4

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
- Check the troubleshooting guide in `docs/TROUBLESHOOTING.md`

## 🎯 Roadmap

- [ ] Phase 2 (Profiling) implementation
- [ ] Phase 3 (KLEE Evaluation) integration
- [ ] Performance optimization
- [ ] Additional utility support
- [ ] Enhanced cloud integration features

---

**Last Updated**: January 21, 2025  
**Version**: 2.0.0  
**Status**: Phase 1 Complete + Cloud Integration