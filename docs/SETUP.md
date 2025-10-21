# EVP-KLEE Setup Guide

This guide provides detailed instructions for setting up the EVP-KLEE development environment.

## Prerequisites

- **Operating System**: Ubuntu 20.04 or compatible Linux distribution
- **Memory**: Minimum 8GB RAM (16GB recommended)
- **Storage**: At least 64GB free space
- **CPU**: Multi-core processor (4+ cores recommended)

## Quick Setup with GitHub Codespace

The easiest way to get started is using GitHub Codespace:

1. Navigate to the repository on GitHub
2. Click the "Code" button
3. Select "Codespaces" → "Create codespace on main"
4. Wait for the environment to build (5-10 minutes)
5. Run `bash scripts/verify_environment.sh` to verify everything is working

## Manual Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/roxaw/evp-klee-artifact.git
cd evp-klee-artifact
```

### Step 2: Install System Dependencies

```bash
sudo apt update
sudo apt install -y build-essential cmake curl git wget vim nano htop time \
    python3 python3-pip python3-venv python3-dev pkg-config \
    libncurses5-dev libncursesw5-dev zlib1g-dev libedit-dev \
    libxml2-dev libzstd-dev libsqlite3-dev libssl-dev libffi-dev \
    libbz2-dev libreadline-dev libgdbm-dev liblzma-dev libtinfo-dev \
    libc6-dev libc++-dev libc++abi-dev
```

### Step 3: Install LLVM 10 and Clang 10

```bash
sudo apt install -y llvm-10 llvm-10-dev llvm-10-tools clang-10 libclang-10-dev

# Create symlinks for easier access
sudo ln -s /usr/bin/llvm-config-10 /usr/bin/llvm-config
sudo ln -s /usr/bin/clang-10 /usr/bin/clang
sudo ln -s /usr/bin/clang++-10 /usr/bin/clang++
sudo ln -s /usr/lib/llvm-10 /usr/lib/llvm
```

### Step 4: Install STP Solver

```bash
cd /tmp
git clone https://github.com/stp/stp.git
cd stp
git checkout 2.3.3
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON ..
make -j$(nproc)
sudo make install
sudo ldconfig
cd / && rm -rf /tmp/stp
```

### Step 5: Install Z3 Solver

```bash
cd /tmp
wget https://github.com/Z3Prover/z3/releases/download/z3-4.8.12/z3-4.8.12-x64-ubuntu-18.04.zip
unzip z3-4.8.12-x64-ubuntu-18.04.zip
sudo cp z3-4.8.12-x64-ubuntu-18.04/bin/z3 /usr/local/bin/
sudo cp z3-4.8.12-x64-ubuntu-18.04/bin/libz3.so /usr/local/lib/
sudo ldconfig
cd / && rm -rf /tmp/z3*
```

### Step 6: Install wllvm

```bash
pip3 install wllvm
```

### Step 7: Run Setup Scripts

```bash
# Initialize the environment
bash scripts/startup_evp_klee.sh

# Build KLEE
bash scripts/build_klee.sh

# Verify everything is working
bash scripts/verify_environment.sh
```

## Environment Configuration

### Environment Variables

The following environment variables are automatically set:

```bash
LLVM_VERSION=10
CLANG_VERSION=10
KLEE_VERSION=2.3
KLEE_SRC=/workspaces/evp-klee-artifact
KLEE_BUILD=/workspaces/evp-klee-artifact/build
LLVM_COMPILER=clang
CC=wllvm
CXX=wllvm++
```

### Python Virtual Environment

A Python virtual environment is created in the `venv/` directory with all required packages:

```bash
# Activate the virtual environment
source venv/bin/activate

# Install additional packages
pip install -r requirements.txt

# Deactivate when done
deactivate
```

## Directory Structure

The setup creates the following directory structure:

```
EVP-KLEE/
├── klee/                 # KLEE v2.3 source
├── benchmarks/           # Test programs
├── scripts/              # Setup scripts
├── experiments/          # Experiment configs
├── docs/                 # Documentation
├── results/              # Analysis results
├── build/                # KLEE build output
└── automated_demo/       # EVP pipeline
```

## Verification

Run the verification script to ensure everything is working:

```bash
bash scripts/verify_environment.sh
```

This will check:
- All required tools are installed
- Environment variables are set correctly
- Python modules are available
- Directory structure is complete
- Git configuration is correct

## Troubleshooting

### Common Issues

1. **Permission denied errors**: Make sure scripts are executable:
   ```bash
   chmod +x scripts/*.sh
   ```

2. **KLEE build fails**: Check that all dependencies are installed:
   ```bash
   bash scripts/verify_environment.sh
   ```

3. **Python module errors**: Activate the virtual environment:
   ```bash
   source venv/bin/activate
   ```

4. **LLVM version mismatch**: Ensure LLVM 10 is installed and configured correctly.

### Getting Help

- Check the logs in `automated_demo/logs/`
- Run `bash scripts/verify_environment.sh` for diagnostics
- See `docs/TROUBLESHOOTING.md` for detailed solutions

## Next Steps

After successful setup:

1. **Test the environment**: Run `python3 test_environment.py`
2. **Run the EVP pipeline**: `cd automated_demo && python3 evp_pipeline.py`
3. **Explore the documentation**: Check `docs/USAGE.md` for usage instructions
4. **Start developing**: The environment is ready for development!
