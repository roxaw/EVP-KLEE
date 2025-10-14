#!/bin/bash
# Generic test harness for coreutils programs
# This script runs basic tests on a given program

set -euo pipefail

PROGRAM="$1"
if [ -z "$PROGRAM" ]; then
    echo "Usage: $0 <program_name>"
    exit 1
fi

echo "Testing program: $PROGRAM"

# Create test directory
TEST_DIR="/tmp/evp_test_${PROGRAM}_$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Set up environment for logging
export VASE_LOG="${VASE_LOG:-/tmp/vase_${PROGRAM}.log}"
export VASE_DIR="${VASE_DIR:-/tmp/vase_${PROGRAM}_dir}"

# Create VASE directory
mkdir -p "$VASE_DIR"

# Basic test cases for different programs
case "$PROGRAM" in
    "cp")
        echo "Testing cp..."
        # Create test files
        echo "test content" > test1.txt
        echo "another test" > test2.txt
        
        # Test basic copy
        cp test1.txt test1_copy.txt
        cp test2.txt test2_copy.txt
        
        # Test directory copy
        mkdir test_dir
        cp test1.txt test_dir/
        cp test2.txt test_dir/
        ;;
        
    "chmod")
        echo "Testing chmod..."
        echo "test file" > test_file.txt
        
        # Test various permissions
        chmod 755 test_file.txt
        chmod 644 test_file.txt
        chmod 777 test_file.txt
        chmod 000 test_file.txt
        chmod 644 test_file.txt
        ;;
        
    "ls")
        echo "Testing ls..."
        # Create test files and directories
        echo "file1" > file1.txt
        echo "file2" > file2.txt
        mkdir dir1 dir2
        
        # Test various ls options
        ls
        ls -l
        ls -a
        ls -la
        ls dir1
        ls dir2
        ;;
        
    "mkdir")
        echo "Testing mkdir..."
        # Test directory creation
        mkdir test_dir1
        mkdir test_dir2
        mkdir -p test_dir3/subdir1/subdir2
        ;;
        
    "rm")
        echo "Testing rm..."
        # Create files to remove
        echo "temp1" > temp1.txt
        echo "temp2" > temp2.txt
        mkdir temp_dir
        
        # Test file removal
        rm temp1.txt
        rm temp2.txt
        rm -rf temp_dir
        ;;
        
    "mv")
        echo "Testing mv..."
        # Create files to move
        echo "move me" > source.txt
        echo "rename me" > old_name.txt
        
        # Test move operations
        mv source.txt destination.txt
        mv old_name.txt new_name.txt
        ;;
        
    "dd")
        echo "Testing dd..."
        # Test basic dd operations
        echo "test data" | dd of=dd_test.txt bs=1 count=9
        dd if=dd_test.txt of=dd_copy.txt bs=1
        ;;
        
    "df")
        echo "Testing df..."
        # Test disk usage
        df
        df -h
        ;;
        
    "du")
        echo "Testing du..."
        # Create test structure
        echo "test" > du_test.txt
        mkdir du_dir
        echo "nested" > du_dir/nested.txt
        
        # Test disk usage
        du
        du -h
        du du_dir
        ;;
        
    "ln")
        echo "Testing ln..."
        echo "link target" > link_target.txt
        
        # Test hard and soft links
        ln link_target.txt hard_link
        ln -s link_target.txt soft_link
        ;;
        
    "split")
        echo "Testing split..."
        # Create a larger file to split
        for i in {1..100}; do
            echo "line $i" >> split_test.txt
        done
        
        # Test splitting
        split -l 10 split_test.txt split_part
        ;;
        
    "touch")
        echo "Testing touch..."
        # Test file creation and timestamp updates
        touch new_file.txt
        touch existing_file.txt
        touch -t 202301011200.00 timestamp_file.txt
        ;;
        
    "rmdir")
        echo "Testing rmdir..."
        # Create empty directories
        mkdir empty_dir1 empty_dir2
        
        # Test directory removal
        rmdir empty_dir1
        rmdir empty_dir2
        ;;
        
    "grep")
        echo "Testing grep..."
        # Create test files with content
        echo "hello world" > test1.txt
        echo "goodbye world" > test2.txt
        echo "hello there" > test3.txt
        
        # Test various grep patterns
        grep "hello" test1.txt
        grep "world" test2.txt
        grep -i "HELLO" test3.txt
        grep -v "world" test1.txt
        ;;
        
    *)
        echo "Unknown program: $PROGRAM"
        echo "Running basic test..."
        # Generic test - just try to run the program with --help
        $PROGRAM --help 2>/dev/null || true
        ;;
esac

# Cleanup
cd /
rm -rf "$TEST_DIR"

echo "Test completed for $PROGRAM"
