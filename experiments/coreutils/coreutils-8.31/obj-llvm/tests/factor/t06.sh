#!/bin/sh

# === THIS IS A TEST SCRIPT DERIVED FROM THE TEMPLATE ../tests/factor/run.sh ===

# Test the factor rewrite.
# The test is to run this command
# seq $START $END | factor | shasum -c --status <(echo $CKSUM  -)
# I.e., to ensure that the factorizations of integers $1..$2
# match what we expect.
#
# See: tests/factor/create-test.sh

# Copyright (C) 2012-2019 Free Software Foundation, Inc.

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src

# Don't run these tests by default.
very_expensive_

print_ver_ factor seq sha1sum

# Template variables.
START=60000000
  END=70000000
CKSUM=689bc70d681791e5d1b8ac1316a05d0c4473d6db

test "$START" = '__ST''ART__' && skip_ 'ignoring factor test template'

echo "$CKSUM  -" > exp

f=1
seq $START $END | factor | sha1sum -c --status exp && f=0

Exit $f
