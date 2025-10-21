#!/bin/bash
# Setup workspace directory structure for EVP-KLEE project

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_status "Setting up EVP-KLEE workspace directory structure..."

# Create main directories
directories=(
    "klee"                    # KLEE v2.3 source
    "benchmarks"              # Test programs
    "scripts"                 # Setup and automation scripts
    "experiments"             # Experiment configs and results
    "docs"                    # Documentation
    "results"                 # Solver statistics
    "build"                   # KLEE build output
    "automated_demo"          # Existing demo scripts
    "automated_demo/config"   # Configuration files
    "automated_demo/drivers"  # Driver programs
    "automated_demo/logs"     # Log files
)

for dir in "${directories[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_success "Created directory: $dir"
    else
        print_status "Directory already exists: $dir"
    fi
done

# Create subdirectories for benchmarks
benchmark_dirs=(
    "benchmarks/coreutils"
    "benchmarks/busybox"
    "benchmarks/apr"
    "benchmarks/m4"
    "benchmarks/custom"
)

for dir in "${benchmark_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_success "Created benchmark directory: $dir"
    fi
done

# Create subdirectories for experiments
experiment_dirs=(
    "experiments/configs"
    "experiments/results"
    "experiments/logs"
    "experiments/scripts"
)

for dir in "${experiment_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_success "Created experiment directory: $dir"
    fi
done

# Create subdirectories for results
result_dirs=(
    "results/klee"
    "results/evp"
    "results/comparison"
    "results/statistics"
)

for dir in "${result_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_success "Created results directory: $dir"
    fi
done

# Create subdirectories for docs
doc_dirs=(
    "docs/images"
    "docs/source"
    "docs/build"
)

for dir in "${doc_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_success "Created documentation directory: $dir"
    fi
done

# Create README files for each main directory
create_readme() {
    local dir="$1"
    local description="$2"
    local readme_file="$dir/README.md"
    
    if [ ! -f "$readme_file" ]; then
        cat > "$readme_file" << EOF
# $description

This directory contains $description for the EVP-KLEE project.

## Contents

- [Add description of contents here]

## Usage

- [Add usage instructions here]

## Notes

- [Add any important notes here]
EOF
        print_success "Created README for $dir"
    fi
}

# Create README files
create_readme "klee" "KLEE symbolic execution engine source code"
create_readme "benchmarks" "Test programs and benchmarks for EVP-KLEE"
create_readme "experiments" "Experiment configurations and results"
create_readme "results" "Analysis results and statistics"
create_readme "docs" "Project documentation"

# Create .gitkeep files for empty directories that should be tracked
gitkeep_dirs=(
    "benchmarks/coreutils"
    "benchmarks/busybox"
    "benchmarks/apr"
    "benchmarks/m4"
    "benchmarks/custom"
    "experiments/configs"
    "experiments/results"
    "experiments/logs"
    "experiments/scripts"
    "results/klee"
    "results/evp"
    "results/comparison"
    "results/statistics"
    "docs/images"
    "docs/source"
    "docs/build"
)

for dir in "${gitkeep_dirs[@]}"; do
    if [ -d "$dir" ] && [ ! -f "$dir/.gitkeep" ]; then
        touch "$dir/.gitkeep"
        print_success "Created .gitkeep for $dir"
    fi
done

print_success "Workspace directory structure setup completed!"
print_status "Directory structure:"
echo ""
echo "EVP-KLEE/"
echo "├── klee/                 # KLEE v2.3 source"
echo "├── benchmarks/           # Test programs"
echo "│   ├── coreutils/        # Coreutils benchmarks"
echo "│   ├── busybox/          # BusyBox benchmarks"
echo "│   ├── apr/              # APR benchmarks"
echo "│   ├── m4/               # M4 benchmarks"
echo "│   └── custom/           # Custom benchmarks"
echo "├── scripts/              # Setup and automation scripts"
echo "├── experiments/          # Experiment configs and results"
echo "│   ├── configs/          # Experiment configurations"
echo "│   ├── results/          # Experiment results"
echo "│   ├── logs/             # Experiment logs"
echo "│   └── scripts/          # Experiment scripts"
echo "├── docs/                 # Documentation"
echo "│   ├── images/           # Documentation images"
echo "│   ├── source/           # Documentation source"
echo "│   └── build/            # Built documentation"
echo "├── results/              # Solver statistics"
echo "│   ├── klee/             # KLEE results"
echo "│   ├── evp/              # EVP results"
echo "│   ├── comparison/       # Comparison results"
echo "│   └── statistics/       # Statistical analysis"
echo "├── build/                # KLEE build output"
echo "└── automated_demo/       # Existing demo scripts"
echo "    ├── config/           # Configuration files"
echo "    ├── drivers/          # Driver programs"
echo "    └── logs/             # Log files"
echo ""
print_status "All directories are ready for use!"
