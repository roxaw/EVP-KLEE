#!/bin/bash

CURRENT_DIR=$(dirname ${BASH_SOURCE[0]})
source ${CURRENT_DIR}/../config.sh
source ${CURRENT_DIR}/../common.sh

UTILS_FILE=${CURRENT_DIR}/utils.txt
LOG_FILE=${CURRENT_DIR}/status.log
INST_FILE=${CURRENT_DIR}/inst.txt
SANDBOX_DIR=/tmp/env
SANDBOX=${SANDBOX_DIR}/sandbox

ARGS="--sym-args 0 1 10 --sym-args 0 2 2 --sym-files 1 8 --sym-stdin 8 --sym-stdout"
MAX_TIME=1800
MAX_TIME_INCREASED=10000
MAX_MEMORY=80000

FLAGS+="--max-memory=${MAX_MEMORY} "
FLAGS+="--search=dfs "
FLAGS+="--use-forked-solver=1 "
FLAGS+="--disable-inlining "
FLAGS+="--libc=uclibc "
FLAGS+="--posix-runtime "
FLAGS+="--external-calls=all "
FLAGS+="--only-output-states-covering-new "
FLAGS+="--env-file=test.env "
FLAGS+="--run-in-dir=${SANDBOX} "
FLAGS+="--watchdog "
FLAGS+="--switch-type=internal "
FLAGS+="--simplify-sym-indices "

function reset {
    rm -rf ${SANDBOX_DIR}
    mkdir -p ${SANDBOX_DIR}
    tar xf ${CURRENT_DIR}/sandbox.tgz -C ${SANDBOX_DIR}
}

function run_klee {
    bc_file=$1
    name=$2
    max_time=$3
    max_inst=$4
    reset
    ${VANILLA_KLEE} ${FLAGS} \
        -output-dir=${OVERHEAD_DIR}/out-klee-${name} \
        -max-time=${max_time} \
        -max-instructions=${max_inst} \
        ${bc_file} ${ARGS} &> /dev/null
}

function run_symaddr {
    bc_file=$1
    name=$2
    max_time=$3
    max_inst=$4
    ${KLEE} ${FLAGS} \
        -output-dir=${OVERHEAD_DIR}/out-mm-${name} \
        -max-time=${max_time} \
        -max-instructions=${max_inst} \
        -use-sym-addr \
        -use-rebase=0 \
        -use-global-id=1 \
        -use-recursive-rebase=1 \
        ${bc_file} ${ARGS} &> /dev/null
}

function run_klee_all {
    log_file=${LOG_FILE}
    rm -rf ${log_file}
    for name in $(cat ${UTILS_FILE}); do
        bc_file=${CURRENT_DIR}/build/src/${name}.bc
        run_klee ${bc_file} ${name} ${MAX_TIME} 0
        echo "${name}: status = $?" >> ${log_file}
    done
}

function run_symaddr_all {
    log_file=${LOG_FILE}
    rm -rf ${log_file}
    for name in $(cat ${UTILS_FILE}); do
        bc_file=${CURRENT_DIR}/build/src/${name}.bc
        run_symaddr ${bc_file} ${name} ${MAX_TIME} 0
        echo "${name}: status = $?" >> ${log_file}
    done
}

function run_with_limit {
    log_file=${LOG_FILE}
    rm -rf ${log_file}
    while IFS= read -r line; do
        name=$(echo ${line} | awk '{ print $1 }')
        max_inst=$(echo ${line} | awk '{ print $2 }')
        bc_file=${CURRENT_DIR}/build/src/${name}.bc
        run_klee ${bc_file} ${name} ${MAX_TIME_INCREASED} ${max_inst}
        echo "${name}: klee status = $?" >> ${log_file}
        run_symaddr ${bc_file} ${name} ${MAX_TIME_INCREASED} ${max_inst}
        echo "${name}: mm status = $?" >> ${log_file}
    done < ${INST_FILE}
}

# Honor OUT_DIR from the environment, otherwise derive a sensible default
_default_out() {
  local label="$1"  # e.g., baseline or vase
  mkdir -p "${RUNS_ROOT}/${label}"
  echo "${RUNS_ROOT}/${label}"
}

run_baseline() {
  local search="$1"          # e.g., "-search=dfs" or ""
  local out="${OUT_DIR:-$(_default_out baseline)}"
  echo "[*] Baseline → ${out}"
  "${VANILLA_KLEE}" ${FLAGS} \
    -output-dir="${out}" \
    ${search} \
    "${BC_FILE}" "${SIZE}"
}

run_vase() {
  local search="$1"
  local out="${OUT_DIR:-$(_default_out vase)}"
  echo "[*] VASE → ${out}"
  "${VASE_KLEE}" ${FLAGS} \
    --use-vase --vase-map="${MAP_FILE}" \
    -output-dir="${out}" \
    ${search} \
    "${BC_FILE}" "${SIZE}"
}

ulimit -s unlimited
