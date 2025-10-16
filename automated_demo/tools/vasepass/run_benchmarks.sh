#!/bin/bash

PASS_SO=./VaseInstrumentPass.so
LOG=vase_value_log.txt
LLVM_OPT=/usr/lib/llvm-10/bin/opt
LLVM_CLANG=clang

mkdir -p instrumented

echo "[*] Cleaning old logs"
rm -f $LOG instrumented/*.bc

for src in benchmarks/*.c; do
    base=$(basename "$src" .c)
    echo "[*] Processing $src"

    # Step 1: Compile to bitcode
    $LLVM_CLANG -g -emit-llvm -c "$src" -o "$base.bc"

    # Step 2: Instrument using your pass
    $LLVM_OPT -load $PASS_SO -vase-instrument < "$base.bc" > "instrumented/$base.inst.bc"

    # Step 3: Execute instrumented binary (JIT)
    lli instrumented/$base.inst.bc

    echo "[+] Done: $src"
    echo
done

echo "[*] Logs saved in $LOG"

