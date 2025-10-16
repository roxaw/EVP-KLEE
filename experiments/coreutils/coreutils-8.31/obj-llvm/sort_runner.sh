#!/usr/bin/env bash
set -euo pipefail

KLEE_BIN=/home/roxana/klee-env/klee-source/klee/build/bin/klee
BC=/home/roxana/Downloads/klee-mm-benchmarks/coreutils/coreutils-8.31/obj-llvm/sort_patched.bc

# Forward args, but tell KLEE to collect values instead of exploring
exec $KLEE_BIN --libc=uclibc --posix-runtime \
     --vase-map=/home/roxana/Downloads/klee-mm-benchmarks/coreutils/evp_artifacts/sort/limitedValuedMap.json \
     --only-output-states-covering-new \
     --exit-on-error-type=Ptr \
     "$BC" -- "$@"
