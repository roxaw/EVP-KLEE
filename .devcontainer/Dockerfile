# EVP-KLEE Development Environment
# Based on Ubuntu 20.04 with LLVM 10, KLEE 2.3, and symbolic execution tools

FROM ubuntu:20.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Set environment variables
ENV LLVM_VERSION=10
ENV CLANG_VERSION=10
ENV KLEE_VERSION=2.3
ENV KLEE_SRC=/workspaces/evp-klee-artifact
ENV KLEE_BUILD=/workspaces/evp-klee-artifact/build
ENV LLVM_COMPILER=clang
ENV CC=wllvm
ENV CXX=wllvm++

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    curl \
    git \
    wget \
    vim \
    nano \
    htop \
    time \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    pkg-config \
    libncurses5-dev \
    libncursesw5-dev \
    zlib1g-dev \
    libedit-dev \
    libxml2-dev \
    libzstd-dev \
    libsqlite3-dev \
    libssl-dev \
    libffi-dev \
    libbz2-dev \
    libreadline-dev \
    libgdbm-dev \
    liblzma-dev \
    libtinfo-dev \
    libc6-dev \
    libc++-dev \
    libc++abi-dev \
    && rm -rf /var/lib/apt/lists/*

# Install LLVM 10 and Clang 10
RUN apt-get update && apt-get install -y \
    llvm-10 \
    llvm-10-dev \
    llvm-10-tools \
    clang-10 \
    libclang-10-dev \
    && rm -rf /var/lib/apt/lists/*

# Create symlinks for easier access
RUN ln -s /usr/bin/llvm-config-10 /usr/bin/llvm-config && \
    ln -s /usr/bin/clang-10 /usr/bin/clang && \
    ln -s /usr/bin/clang++-10 /usr/bin/clang++ && \
    ln -s /usr/lib/llvm-10 /usr/lib/llvm

# Install STP solver
RUN cd /tmp && \
    git clone https://github.com/stp/stp.git && \
    cd stp && \
    git checkout 2.3.3 && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON .. && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    cd / && rm -rf /tmp/stp

# Install Z3 solver (version 4.8.12 - compatible with KLEE 2.3)
RUN cd /tmp && \
    wget https://github.com/Z3Prover/z3/releases/download/z3-4.8.12/z3-4.8.12-x64-ubuntu-18.04.zip && \
    unzip z3-4.8.12-x64-ubuntu-18.04.zip && \
    cp z3-4.8.12-x64-ubuntu-18.04/bin/z3 /usr/local/bin/ && \
    cp z3-4.8.12-x64-ubuntu-18.04/bin/libz3.so /usr/local/lib/ && \
    ldconfig && \
    cd / && rm -rf /tmp/z3*

# Install wllvm (whole-program LLVM)
RUN pip3 install wllvm

# Install additional Python packages
RUN pip3 install \
    pytest>=7.0.0 \
    pathlib2 \
    json5 \
    subprocess32

# Create workspace directory
RUN mkdir -p /workspaces/evp-klee-artifact

# Set working directory
WORKDIR /workspaces/evp-klee-artifact

# Create vscode user for development
RUN useradd -m -s /bin/bash vscode && \
    usermod -aG sudo vscode && \
    echo "vscode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to vscode user
USER vscode

# Set up environment for vscode user
RUN echo 'export LLVM_VERSION=10' >> ~/.bashrc && \
    echo 'export CLANG_VERSION=10' >> ~/.bashrc && \
    echo 'export KLEE_VERSION=2.3' >> ~/.bashrc && \
    echo 'export KLEE_SRC=/workspaces/evp-klee-artifact' >> ~/.bashrc && \
    echo 'export KLEE_BUILD=/workspaces/evp-klee-artifact/build' >> ~/.bashrc && \
    echo 'export LLVM_COMPILER=clang' >> ~/.bashrc && \
    echo 'export CC=wllvm' >> ~/.bashrc && \
    echo 'export CXX=wllvm++' >> ~/.bashrc && \
    echo 'export PATH=$KLEE_BUILD/bin:$PATH' >> ~/.bashrc && \
    echo 'export PS1="\[\033[01;32m\]EVP-KLEE\[\033[00m\]:\w\$ "' >> ~/.bashrc

# Create directory structure
RUN mkdir -p klee benchmarks scripts experiments docs results build

# Set proper permissions
RUN chmod -R 755 /workspaces/evp-klee-artifact

# Keep container running
CMD ["/bin/bash"]
