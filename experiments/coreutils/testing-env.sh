# testing-env.sh  (source this before running tests)
export LC_ALL=C
export TZ=UTC
export PATH="/bin:/usr/bin"
export TERM="dumb"          # avoid color/terminfo branches
export LS_COLORS=           # empty to disable palette-based paths
unset COLORTERM

export HOME="$PWD/sandbox"
export TMPDIR="$PWD/sandbox/tmp"
mkdir -p "$HOME" "$TMPDIR"

export UMASK=022
umask 022

# Stabilize size/format-dependent paths
export BLOCK_SIZE=1K
export DF_BLOCK_SIZE=1K
export DU_BLOCK_SIZE=1K
export LS_BLOCK_SIZE=1K

export COLUMNS=80
