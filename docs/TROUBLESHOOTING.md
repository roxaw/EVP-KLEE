# EVP-KLEE Troubleshooting Guide

This guide helps you diagnose and fix common issues with the EVP-KLEE pipeline.

## Quick Diagnostics

### Environment Check

First, verify your environment is set up correctly:

```bash
bash scripts/verify_environment.sh
```

This will check all tools, environment variables, and configurations.

### Test Environment

Run the basic environment test:

```bash
python3 test_environment.py
```

## Common Issues and Solutions

### 1. KLEE Not Found

**Error**: `klee: command not found`

**Causes**:
- KLEE not built yet
- PATH not configured correctly
- Build failed

**Solutions**:

```bash
# Build KLEE
bash scripts/build_klee.sh

# Check if KLEE is in PATH
echo $PATH | grep -o "build/bin"

# Add to PATH manually
export PATH=$KLEE_BUILD/bin:$PATH
```

### 2. LLVM Version Mismatch

**Error**: `LLVM version mismatch` or `clang-10: command not found`

**Causes**:
- Wrong LLVM version installed
- Clang not found
- Environment variables not set

**Solutions**:

```bash
# Check LLVM version
llvm-config-10 --version

# Check Clang version
clang-10 --version

# Reinstall LLVM 10
sudo apt install --reinstall llvm-10 clang-10

# Update environment
source .env
```

### 3. Python Module Errors

**Error**: `ModuleNotFoundError: No module named 'json'`

**Causes**:
- Virtual environment not activated
- Python packages not installed
- Wrong Python version

**Solutions**:

```bash
# Activate virtual environment
source venv/bin/activate

# Install requirements
pip install -r requirements.txt

# Check Python version
python3 --version
```

### 4. Permission Denied

**Error**: `Permission denied` when running scripts

**Causes**:
- Scripts not executable
- Wrong file permissions
- User not in correct group

**Solutions**:

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Check permissions
ls -la scripts/

# Fix ownership if needed
sudo chown -R $USER:$USER .
```

### 5. Build Failures

**Error**: KLEE build fails with CMake or make errors

**Causes**:
- Missing dependencies
- Insufficient memory
- Disk space full
- Compiler errors

**Solutions**:

```bash
# Check available memory
free -h

# Check disk space
df -h

# Install missing dependencies
sudo apt install build-essential cmake

# Clean and rebuild
rm -rf build/*
bash scripts/build_klee.sh
```

### 6. Solver Issues

**Error**: `STP not found` or `Z3 not found`

**Causes**:
- Solvers not installed
- PATH not configured
- Library linking issues

**Solutions**:

```bash
# Check solver installation
stp --version
z3 --version

# Reinstall solvers
bash scripts/build_klee.sh  # This will reinstall solvers

# Check library paths
ldconfig -p | grep -E "(stp|z3)"
```

### 7. Memory Issues

**Error**: `Out of memory` or `Killed`

**Causes**:
- Insufficient RAM
- Large programs consuming too much memory
- Memory leaks

**Solutions**:

```bash
# Check memory usage
htop

# Reduce parallel jobs
export EVP_PARALLEL_JOBS=1

# Increase swap space
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### 8. File System Issues

**Error**: `No space left on device`

**Causes**:
- Disk full
- Too many artifacts
- Large log files

**Solutions**:

```bash
# Check disk usage
df -h

# Clean up old artifacts
rm -rf evp_artifacts/klee-out-*
rm -rf build/klee-out-*

# Clean up logs
find logs/ -name "*.log" -mtime +7 -delete

# Compress old results
tar -czf old_results.tar.gz results/
rm -rf results/*
```

## Debug Mode

### Enable Debug Logging

```bash
# Set debug environment variable
export EVP_DEBUG=1

# Run with verbose output
python3 evp_pipeline.py --verbose
```

### Check Log Files

```bash
# View recent logs
ls -la logs/

# Monitor live execution
tail -f logs/evp_*.log

# Check specific error
grep -i error logs/evp_*.log
```

### Debug KLEE Execution

```bash
# Run KLEE with debug output
klee --debug-print-instructions --debug-print-constraints program.bc

# Check KLEE logs
ls -la klee-out-*/
cat klee-out-*/info
```

## Performance Issues

### Slow Execution

**Symptoms**: Pipeline takes too long to complete

**Solutions**:

```bash
# Reduce number of programs
python3 evp_pipeline.py --program cp coreutils

# Use smaller test suites
# Edit config/programs.json to include fewer programs

# Increase parallel jobs (if you have enough memory)
export EVP_PARALLEL_JOBS=4
```

### High Memory Usage

**Symptoms**: System becomes unresponsive

**Solutions**:

```bash
# Monitor memory usage
htop

# Reduce parallel jobs
export EVP_PARALLEL_JOBS=1

# Use smaller programs for testing
python3 evp_pipeline.py --program ls coreutils
```

## Configuration Issues

### Invalid Configuration

**Error**: JSON parsing errors or invalid configuration

**Solutions**:

```bash
# Validate JSON syntax
python3 -m json.tool config/programs.json

# Check configuration format
cat config/programs.json | jq .
```

### Missing Programs

**Error**: Programs not found or not executable

**Solutions**:

```bash
# Check if programs exist
which cp chmod dd

# Check program permissions
ls -la /bin/cp

# Update configuration with correct paths
```

## Network Issues

### Git LFS Problems

**Error**: Large files not downloaded properly

**Solutions**:

```bash
# Initialize Git LFS
git lfs install

# Pull LFS files
git lfs pull

# Check LFS status
git lfs status
```

### Download Failures

**Error**: Cannot download dependencies

**Solutions**:

```bash
# Check internet connection
ping google.com

# Use different mirror
export APT_MIRROR=http://archive.ubuntu.com/ubuntu/

# Download manually
wget https://github.com/Z3Prover/z3/releases/download/z3-4.8.12/z3-4.8.12-x64-ubuntu-18.04.zip
```

## Recovery Procedures

### Complete Reset

If everything is broken, reset the environment:

```bash
# Clean everything
rm -rf build/ klee/ venv/ evp_artifacts/

# Reinstall everything
bash scripts/startup_evp_klee.sh
bash scripts/build_klee.sh
```

### Partial Reset

Reset specific components:

```bash
# Reset Python environment
rm -rf venv/
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Reset KLEE build
rm -rf build/*
bash scripts/build_klee.sh
```

## Getting Help

### Log Collection

When reporting issues, collect these logs:

```bash
# Environment information
bash scripts/verify_environment.sh > environment.log

# System information
uname -a > system.log
free -h >> system.log
df -h >> system.log

# Recent error logs
tail -n 100 logs/evp_*.log > recent_errors.log
```

### Debug Information

```bash
# Create debug package
tar -czf evp_debug_$(date +%Y%m%d_%H%M%S).tar.gz \
    environment.log system.log recent_errors.log \
    config/ scripts/ .env
```

### Support Channels

- Check this troubleshooting guide first
- Review the main README.md
- Check GitHub issues for similar problems
- Run `bash scripts/verify_environment.sh` for diagnostics

## Prevention

### Regular Maintenance

```bash
# Weekly cleanup
find logs/ -name "*.log" -mtime +7 -delete
find evp_artifacts/ -name "klee-out-*" -mtime +30 -exec rm -rf {} \;

# Monthly verification
bash scripts/verify_environment.sh
```

### Monitoring

```bash
# Set up monitoring
watch -n 5 'df -h; free -h; ps aux | grep -E "(klee|python)"'
```

### Backup

```bash
# Backup important configurations
tar -czf evp_config_backup.tar.gz config/ .env scripts/
```
