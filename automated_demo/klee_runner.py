#!/usr/bin/env python3
"""
KLEE Runner Module for EVP Pipeline

This module encapsulates the KLEE execution logic from step3_generic.sh
and provides a Python interface for running both vanilla and EVP-enabled KLEE.
"""

import os
import subprocess
import tempfile
import shutil
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import json


class KLEERunner:
    """Handles KLEE execution for both vanilla and EVP-enabled runs"""
    
    def __init__(self, klee_bin: str, project_root: Path, config: dict = None):
        self.klee_bin = klee_bin
        self.project_root = project_root
        self.config = config or {}
        
        # Base KLEE flags from step3_generic.sh
        self.klee_flags_base = [
            "--libc=uclibc", "--posix-runtime", "--simplify-sym-indices", 
            "--write-cvcs", "--write-cov", "--stats", "--write-smt2s",
            "--output-module", "--max-memory=1000", "--disable-inlining", 
            "--optimize", "--use-forked-solver", "--use-cex-cache", 
            "--external-calls=all", "--only-output-states-covering-new",
            "--max-sym-array-size=4096", "--max-solver-time=30s", 
            "--max-time=1800s", "--watchdog", "--max-memory-inhibit=false",
            "--max-static-fork-pct=1", "--max-static-solve-pct=1", 
            "--max-static-cpfork-pct=1", "--switch-type=internal", 
            "--search=random-path", "--search=nurs:covnew",
            "--use-batching-search", "--batch-instructions=10000"
        ]
        
        # Symbolic input configurations per utility
        self.symbolic_inputs = {
            "ls": "--sym-args 0 2 8 --sym-files 1 32",
            "touch": "--sym-args 0 2 8 --sym-files 1 16", 
            "cp": "--sym-args 2 2 8 --sym-files 2 32",
            "du": "--sym-args 0 1 8 --sym-files 1 32",
            "stat": "--sym-args 1 1 8",
            "chmod": "--sym-args 2 2 8 --sym-files 1 16",
            "sort": "--sym-args 0 4 8 --sym-stdin 2048 --sym-files 2 4096 A B",
            "mv": "--sym-args 2 2 8 --sym-files 2 16",
            "ln": "--sym-args 2 2 8",
            "shred": "--sym-files 1 32 --sym-args 0 1 8",
            "wc": "--sym-args 0 6 10 --sym-stdin 4096 --sym-files 3 4096 A B C",
            "tail": "--sym-args 0 6 12 --sym-stdin 4096 --sym-files 3 4096 -- A B C",
            "grep": "--sym-args 0 4 8 --sym-files 2 32 A B",
            "mkdir": "--sym-args 1 2 8",
            "rm": "--sym-args 1 2 8 --sym-files 1 16",
            "rmdir": "--sym-args 1 2 8",
            "dd": "--sym-args 0 6 12 --sym-files 2 32 A B",
            "df": "--sym-args 0 2 8",
            "split": "--sym-args 0 4 8 --sym-files 1 64",
            "chown": "--sym-args 2 2 8 --sym-files 1 16",
            "chgrp": "--sym-args 2 2 8 --sym-files 1 16",
            "cat": "--sym-args 0 2 8 --sym-files 1 32",
            "head": "--sym-args 0 4 8 --sym-files 1 32",
            "tr": "--sym-args 0 2 8 --sym-stdin 1024",
            "cut": "--sym-args 0 4 8 --sym-files 1 32",
            "uniq": "--sym-args 0 2 8 --sym-files 1 32",
            "join": "--sym-args 0 2 8 --sym-files 2 32 A B",
            "paste": "--sym-args 0 2 8 --sym-files 2 32 A B",
            "comm": "--sym-args 0 2 8 --sym-files 2 32 A B",
            "diff": "--sym-args 0 2 8 --sym-files 2 32 A B",
            "cmp": "--sym-args 0 2 8 --sym-files 2 32 A B",
            "od": "--sym-args 0 4 8 --sym-files 1 32",
            "hexdump": "--sym-args 0 4 8 --sym-files 1 32",
            "base64": "--sym-args 0 2 8 --sym-files 1 32",
            "truncate": "--sym-args 1 2 8 --sym-files 1 16",
            "yes": "--sym-args 0 1 8",
            "seq": "--sym-args 0 3 8",
            "factor": "--sym-args 0 1 8",
            "pr": "--sym-args 0 4 8 --sym-files 1 32",
            "fold": "--sym-args 0 2 8 --sym-files 1 32",
            "fmt": "--sym-args 0 2 8 --sym-files 1 32",
            "expand": "--sym-args 0 2 8 --sym-files 1 32",
            "unexpand": "--sym-args 0 2 8 --sym-files 1 32",
            "nl": "--sym-args 0 2 8 --sym-files 1 32",
            "csplit": "--sym-args 1 2 8 --sym-files 1 32",
            "tac": "--sym-args 0 2 8 --sym-files 1 32",
            "rev": "--sym-args 0 2 8 --sym-files 1 32",
            "shuf": "--sym-args 0 2 8 --sym-files 1 32",
            "sum": "--sym-args 0 2 8 --sym-files 1 32",
            "cksum": "--sym-args 0 2 8 --sym-files 1 32",
            "md5sum": "--sym-args 0 2 8 --sym-files 1 32",
            "sha1sum": "--sym-args 0 2 8 --sym-files 1 32",
            "sha224sum": "--sym-args 0 2 8 --sym-files 1 32",
            "sha256sum": "--sym-args 0 2 8 --sym-files 1 32",
            "sha384sum": "--sym-args 0 2 8 --sym-files 1 32",
            "sha512sum": "--sym-args 0 2 8 --sym-files 1 32",
            "b2sum": "--sym-args 0 2 8 --sym-files 1 32",
            "basename": "--sym-args 1 2 8",
            "dirname": "--sym-args 1 2 8",
            "pathchk": "--sym-args 1 2 8",
            "mktemp": "--sym-args 0 2 8",
            "realpath": "--sym-args 1 2 8",
            "readlink": "--sym-args 1 2 8",
            "link": "--sym-args 2 2 8",
            "unlink": "--sym-args 1 1 8",
            "hostid": "--sym-args 0 0 0",
            "nproc": "--sym-args 0 1 8",
            "whoami": "--sym-args 0 0 0",
            "id": "--sym-args 0 2 8",
            "logname": "--sym-args 0 0 0",
            "groups": "--sym-args 0 0 0",
            "users": "--sym-args 0 0 0",
            "who": "--sym-args 0 2 8",
            "uptime": "--sym-args 0 0 0",
            "date": "--sym-args 0 2 8",
            "arch": "--sym-args 0 0 0",
            "uname": "--sym-args 0 2 8",
            "hostname": "--sym-args 0 1 8",
            "dircolors": "--sym-args 0 1 8",
            "tty": "--sym-args 0 0 0",
            "pwd": "--sym-args 0 0 0",
            "stty": "--sym-args 0 2 8",
            "printenv": "--sym-args 0 1 8",
            "env": "--sym-args 0 2 8",
            "nice": "--sym-args 1 2 8 --sym-files 1 16",
            "nohup": "--sym-args 1 2 8 --sym-files 1 16",
            "timeout": "--sym-args 1 2 8 --sym-files 1 16",
            "stdbuf": "--sym-args 1 2 8 --sym-files 1 16",
            "runcon": "--sym-args 1 2 8 --sym-files 1 16",
            "chroot": "--sym-args 1 2 8 --sym-files 1 16",
            "chcon": "--sym-args 1 2 8 --sym-files 1 16",
            "getfacl": "--sym-args 0 2 8 --sym-files 1 16",
            "setfacl": "--sym-args 1 2 8 --sym-files 1 16",
            "chacl": "--sym-args 1 2 8 --sym-files 1 16",
            "install": "--sym-args 2 4 8 --sym-files 2 32 A B",
            "mknod": "--sym-args 2 3 8",
            "mkfifo": "--sym-args 1 2 8",
            "mkswap": "--sym-args 1 2 8",
            "swapon": "--sym-args 0 2 8",
            "swapoff": "--sym-args 0 2 8",
            "sync": "--sym-args 0 0 0",
            "fsync": "--sym-args 0 0 0",
            "fdatasync": "--sym-args 0 0 0",
            "mount": "--sym-args 0 4 8",
            "umount": "--sym-args 0 2 8",
            "df": "--sym-args 0 2 8",
            "du": "--sym-args 0 2 8 --sym-files 1 32",
            "stat": "--sym-args 1 2 8",
            "ls": "--sym-args 0 2 8 --sym-files 1 32",
            "dir": "--sym-args 0 2 8 --sym-files 1 32",
            "vdir": "--sym-args 0 2 8 --sym-files 1 32",
            "dircolors": "--sym-args 0 1 8",
            "chmod": "--sym-args 2 2 8 --sym-files 1 16",
            "chown": "--sym-args 2 2 8 --sym-files 1 16",
            "chgrp": "--sym-args 2 2 8 --sym-files 1 16",
            "chcon": "--sym-args 1 2 8 --sym-files 1 16",
            "runcon": "--sym-args 1 2 8 --sym-files 1 16",
            "touch": "--sym-args 0 2 8 --sym-files 1 16",
            "mkdir": "--sym-args 1 2 8",
            "mknod": "--sym-args 2 3 8",
            "mkfifo": "--sym-args 1 2 8",
            "rm": "--sym-args 1 2 8 --sym-files 1 16",
            "rmdir": "--sym-args 1 2 8",
            "unlink": "--sym-args 1 1 8",
            "cp": "--sym-args 2 2 8 --sym-files 2 32",
            "mv": "--sym-args 2 2 8 --sym-files 2 16",
            "ln": "--sym-args 2 2 8",
            "link": "--sym-args 2 2 8",
            "readlink": "--sym-args 1 2 8",
            "realpath": "--sym-args 1 2 8",
            "basename": "--sym-args 1 2 8",
            "dirname": "--sym-args 1 2 8",
            "pathchk": "--sym-args 1 2 8",
            "mktemp": "--sym-args 0 2 8",
            "install": "--sym-args 2 4 8 --sym-files 2 32 A B",
            "cat": "--sym-args 0 2 8 --sym-files 1 32",
            "tac": "--sym-args 0 2 8 --sym-files 1 32",
            "rev": "--sym-args 0 2 8 --sym-files 1 32",
            "head": "--sym-args 0 4 8 --sym-files 1 32",
            "tail": "--sym-args 0 6 12 --sym-stdin 4096 --sym-files 3 4096 -- A B C",
            "split": "--sym-args 0 4 8 --sym-files 1 64",
            "csplit": "--sym-args 1 2 8 --sym-files 1 32",
            "wc": "--sym-args 0 6 10 --sym-stdin 4096 --sym-files 3 4096 A B C",
            "sum": "--sym-args 0 2 8 --sym-files 1 32",
            "cksum": "--sym-args 0 2 8 --sym-files 1 32",
            "md5sum": "--sym-args 0 2 8 --sym-files 1 32",
            "sha1sum": "--sym-args 0 2 8 --sym-files 1 32",
            "sha224sum": "--sym-args 0 2 8 --sym-files 1 32",
            "sha256sum": "--sym-args 0 2 8 --sym-files 1 32",
            "sha384sum": "--sym-args 0 2 8 --sym-files 1 32",
            "sha512sum": "--sym-args 0 2 8 --sym-files 1 32",
            "b2sum": "--sym-args 0 2 8 --sym-files 1 32",
            "sort": "--sym-args 0 4 8 --sym-stdin 2048 --sym-files 2 4096 A B",
            "shuf": "--sym-args 0 2 8 --sym-files 1 32",
            "uniq": "--sym-args 0 2 8 --sym-files 1 32",
            "comm": "--sym-args 0 2 8 --sym-files 2 32 A B",
            "join": "--sym-args 0 2 8 --sym-files 2 32 A B",
            "paste": "--sym-args 0 2 8 --sym-files 2 32 A B",
            "cut": "--sym-args 0 4 8 --sym-files 1 32",
            "tr": "--sym-args 0 2 8 --sym-stdin 1024",
            "expand": "--sym-args 0 2 8 --sym-files 1 32",
            "unexpand": "--sym-args 0 2 8 --sym-files 1 32",
            "fold": "--sym-args 0 2 8 --sym-files 1 32",
            "fmt": "--sym-args 0 2 8 --sym-files 1 32",
            "pr": "--sym-args 0 4 8 --sym-files 1 32",
            "nl": "--sym-args 0 2 8 --sym-files 1 32",
            "od": "--sym-args 0 4 8 --sym-files 1 32",
            "hexdump": "--sym-args 0 4 8 --sym-files 1 32",
            "base64": "--sym-args 0 2 8 --sym-files 1 32",
            "truncate": "--sym-args 1 2 8 --sym-files 1 16",
            "dd": "--sym-args 0 6 12 --sym-files 2 32 A B",
            "grep": "--sym-args 0 4 8 --sym-files 2 32 A B",
            "egrep": "--sym-args 0 4 8 --sym-files 2 32 A B",
            "fgrep": "--sym-args 0 4 8 --sym-files 2 32 A B",
            "yes": "--sym-args 0 1 8",
            "seq": "--sym-args 0 3 8",
            "factor": "--sym-args 0 1 8",
            "shred": "--sym-files 1 32 --sym-args 0 1 8",
            "test": "--sym-args 1 3 8",
            "true": "--sym-args 0 0 0",
            "false": "--sym-args 0 0 0",
            "echo": "--sym-args 0 2 8",
            "printf": "--sym-args 0 2 8",
            "sleep": "--sym-args 1 1 8",
            "timeout": "--sym-args 1 2 8 --sym-files 1 16",
            "kill": "--sym-args 1 2 8",
            "killall": "--sym-args 1 2 8",
            "pkill": "--sym-args 1 2 8",
            "ps": "--sym-args 0 2 8",
            "pgrep": "--sym-args 1 2 8",
            "pstree": "--sym-args 0 2 8",
            "top": "--sym-args 0 2 8",
            "htop": "--sym-args 0 2 8",
            "free": "--sym-args 0 2 8",
            "vmstat": "--sym-args 0 2 8",
            "iostat": "--sym-args 0 2 8",
            "sar": "--sym-args 0 2 8",
            "mpstat": "--sym-args 0 2 8",
            "pidstat": "--sym-args 0 2 8",
            "lscpu": "--sym-args 0 2 8",
            "lsmem": "--sym-args 0 2 8",
            "lsblk": "--sym-args 0 2 8",
            "lsusb": "--sym-args 0 2 8",
            "lspci": "--sym-args 0 2 8",
            "lsmod": "--sym-args 0 2 8",
            "modinfo": "--sym-args 1 2 8",
            "modprobe": "--sym-args 1 2 8",
            "rmmod": "--sym-args 1 2 8",
            "insmod": "--sym-args 1 2 8",
            "depmod": "--sym-args 0 2 8",
            "lsmod": "--sym-args 0 2 8",
            "lsdev": "--sym-args 0 2 8",
            "lsattr": "--sym-args 0 2 8 --sym-files 1 16",
            "chattr": "--sym-args 1 2 8 --sym-files 1 16",
            "lsattr": "--sym-args 0 2 8 --sym-files 1 16",
            "chattr": "--sym-args 1 2 8 --sym-files 1 16",
            "getfattr": "--sym-args 0 2 8 --sym-files 1 16",
            "setfattr": "--sym-args 1 2 8 --sym-files 1 16",
            "getfacl": "--sym-args 0 2 8 --sym-files 1 16",
            "setfacl": "--sym-args 1 2 8 --sym-files 1 16",
            "chacl": "--sym-args 1 2 8 --sym-files 1 16",
            "getcap": "--sym-args 0 2 8 --sym-files 1 16",
            "setcap": "--sym-args 1 2 8 --sym-files 1 16",
            "getsebool": "--sym-args 0 2 8",
            "setsebool": "--sym-args 1 2 8",
            "sestatus": "--sym-args 0 2 8",
            "semanage": "--sym-args 1 2 8",
            "restorecon": "--sym-args 0 2 8 --sym-files 1 16",
            "fixfiles": "--sym-args 0 2 8 --sym-files 1 16",
            "auditctl": "--sym-args 1 2 8",
            "ausearch": "--sym-args 0 2 8",
            "aureport": "--sym-args 0 2 8",
            "autrace": "--sym-args 1 2 8",
            "auparse": "--sym-args 0 2 8",
            "ausyscall": "--sym-args 0 2 8",
            "aulast": "--sym-args 0 2 8",
            "aulastlog": "--sym-args 0 2 8",
            "aureport": "--sym-args 0 2 8",
            "ausearch": "--sym-args 0 2 8",
            "autrace": "--sym-args 1 2 8",
            "auparse": "--sym-args 0 2 8",
            "ausyscall": "--sym-args 0 2 8",
            "aulast": "--sym-args 0 2 8",
            "aulastlog": "--sym-args 0 2 8",
            "aureport": "--sym-args 0 2 8",
            "ausearch": "--sym-args 0 2 8",
            "autrace": "--sym-args 1 2 8",
            "auparse": "--sym-args 0 2 8",
            "ausyscall": "--sym-args 0 2 8",
            "aulast": "--sym-args 0 2 8",
            "aulastlog": "--sym-args 0 2 8"
        }
    
    def get_symbolic_input(self, program: str, category: str = None) -> str:
        """Get symbolic input configuration for a program"""
        # First try to get from config file
        if category and category in self.config:
            klee_config = self.config[category].get("klee_config", {})
            symbolic_inputs = klee_config.get("symbolic_inputs", {})
            if program in symbolic_inputs:
                return symbolic_inputs[program]
        
        # Fall back to built-in configurations
        return self.symbolic_inputs.get(program, "--sym-args 0 2 8 --sym-files 1 16")
    
    def prepare_sandbox(self, sandbox_dir: Path) -> None:
        """Prepare sandbox directory with test files"""
        if sandbox_dir.exists():
            shutil.rmtree(sandbox_dir)
        sandbox_dir.mkdir(parents=True, exist_ok=True)
        
        # Create test directory structure
        dir_a = sandbox_dir / "dirA"
        dir_a.mkdir()
        subdir = dir_a / "subdir"
        subdir.mkdir()
        
        # Create test files
        (dir_a / "a.txt").write_text("hello")
        (subdir / "b.txt").write_text("world")
    
    def run_klee(self, 
                 bitcode_path: Path,
                 output_dir: Path,
                 map_file: Optional[Path] = None,
                 program: str = "",
                 category: str = "",
                 extra_args: List[str] = None,
                 test_env: Optional[Path] = None,
                 run_id: str = "",
                 use_evp: bool = False) -> Tuple[bool, str, int]:
        """
        Run KLEE on the given bitcode
        
        Args:
            bitcode_path: Path to the bitcode file
            output_dir: Output directory for KLEE results
            map_file: Path to VASE map file (for EVP runs)
            program: Program name for symbolic input configuration
            extra_args: Extra program arguments
            test_env: Path to test environment file
            run_id: Run identifier for logging
            use_evp: Whether to use EVP/VASE features
            
        Returns:
            Tuple of (success, output, exit_code)
        """
        if extra_args is None:
            extra_args = []
            
        # Create temporary sandbox
        with tempfile.TemporaryDirectory(prefix=f"{program}-klee-") as sandbox_dir:
            self.prepare_sandbox(Path(sandbox_dir))
            
            # Prepare output directory
            if output_dir.exists():
                shutil.rmtree(output_dir)
            output_dir.mkdir(parents=True)
            
            # Build KLEE command
            cmd = [self.klee_bin]
            
            # Add base flags
            cmd.extend(self.klee_flags_base)
            
            # Add EVP-specific flags
            if use_evp and map_file:
                cmd.extend(["--use-vase", f"--vase-map={map_file}"])
            
            # Add test environment if provided
            if test_env and test_env.exists():
                cmd.append(f"--env-file={test_env}")
            
            # Add sandbox directory
            cmd.append(f"--run-in-dir={sandbox_dir}")
            
            # Add output directory
            cmd.append(f"--output-dir={output_dir}")
            
            # Add bitcode file
            cmd.append(str(bitcode_path))
            
            # Add symbolic input configuration
            symbolic_input = self.get_symbolic_input(program, category)
            cmd.extend(symbolic_input.split())
            
            # Add extra program arguments
            cmd.extend(extra_args)
            
            # Run KLEE
            print(f"[RUN] {'EVP' if use_evp else 'Vanilla'} KLEE on {program}")
            print(f"[CMD] {' '.join(cmd)}")
            
            try:
                result = subprocess.run(
                    cmd, 
                    capture_output=True, 
                    text=True, 
                    timeout=1800  # 30 minutes timeout
                )
                
                success = result.returncode == 0
                output = result.stdout + result.stderr
                
                # Count generated test cases
                ktest_count = len(list(output_dir.glob("test*.ktest")))
                print(f"[OK] {'EVP' if use_evp else 'Vanilla'} KLEE completed; generated {ktest_count} ktests")
                
                return success, output, result.returncode
                
            except subprocess.TimeoutExpired:
                print(f"[TIMEOUT] {'EVP' if use_evp else 'Vanilla'} KLEE timed out after 30 minutes")
                return False, "KLEE execution timed out", -1
            except Exception as e:
                print(f"[ERROR] {'EVP' if use_evp else 'Vanilla'} KLEE failed: {e}")
                return False, str(e), -1
    
    def run_parallel_evaluation(self,
                               bitcode_path: Path,
                               map_file: Path,
                               program: str,
                               category: str = "",
                               run_id: str = "",
                               extra_args: List[str] = None,
                               test_env: Optional[Path] = None) -> Dict:
        """
        Run both vanilla and EVP KLEE in parallel and return results
        
        Args:
            bitcode_path: Path to the bitcode file
            map_file: Path to VASE map file
            program: Program name
            run_id: Run identifier
            extra_args: Extra program arguments
            test_env: Path to test environment file
            
        Returns:
            Dictionary with results from both runs
        """
        if extra_args is None:
            extra_args = []
            
        if not run_id:
            run_id = datetime.now().strftime("%Y%m%d-%H%M%S")
        
        # Create output directories
        base_dir = bitcode_path.parent
        vanilla_out = base_dir / f"klee-vanilla-out-{run_id}"
        evp_out = base_dir / f"klee-evp-out-{run_id}"
        
        print(f"[PHASE 3] Running parallel KLEE evaluation for {program}")
        
        # Run both variants
        vanilla_success, vanilla_output, vanilla_exit = self.run_klee(
            bitcode_path, vanilla_out, None, program, category, extra_args, test_env, run_id, False
        )
        
        evp_success, evp_output, evp_exit = self.run_klee(
            bitcode_path, evp_out, map_file, program, category, extra_args, test_env, run_id, True
        )
        
        # Parse results
        vanilla_stats = self.parse_klee_stats(vanilla_out / "info")
        evp_stats = self.parse_klee_stats(evp_out / "info")
        
        # Count test cases
        vanilla_ktests = len(list(vanilla_out.glob("test*.ktest"))) if vanilla_out.exists() else 0
        evp_ktests = len(list(evp_out.glob("test*.ktest"))) if evp_out.exists() else 0
        
        return {
            "program": program,
            "run_id": run_id,
            "vanilla": {
                "success": vanilla_success,
                "exit_code": vanilla_exit,
                "output_dir": str(vanilla_out),
                "ktest_count": vanilla_ktests,
                "stats": vanilla_stats,
                "output": vanilla_output
            },
            "evp": {
                "success": evp_success,
                "exit_code": evp_exit,
                "output_dir": str(evp_out),
                "ktest_count": evp_ktests,
                "stats": evp_stats,
                "output": evp_output
            }
        }
    
    def parse_klee_stats(self, info_file: Path) -> Dict[str, str]:
        """Parse KLEE info file for statistics"""
        stats = {}
        if info_file.exists():
            try:
                with open(info_file) as f:
                    for line in f:
                        if ":" in line:
                            key, val = line.strip().split(":", 1)
                            stats[key.strip()] = val.strip()
            except Exception as e:
                print(f"[WARNING] Failed to parse KLEE stats from {info_file}: {e}")
        return stats
    
    def compare_results(self, vanilla_stats: Dict, evp_stats: Dict, program: str) -> None:
        """Compare and display results from vanilla and EVP runs"""
        print(f"\n[RESULTS] {program}:")
        
        # Key metrics to compare
        metrics = ["QueryTime", "SolverTime", "WallTime", "NumQueries", "NumStates", "NumInstructions"]
        
        for metric in metrics:
            if metric in vanilla_stats and metric in evp_stats:
                try:
                    v_val = float(vanilla_stats[metric])
                    e_val = float(evp_stats[metric])
                    if v_val > 0:
                        improvement = ((v_val - e_val) / v_val) * 100
                        print(f"  {metric}: {improvement:.2f}% improvement (vanilla: {v_val}, evp: {e_val})")
                    else:
                        print(f"  {metric}: N/A (vanilla: {v_val}, evp: {e_val})")
                except (ValueError, TypeError):
                    print(f"  {metric}: {vanilla_stats[metric]} vs {evp_stats[metric]}")
            else:
                if metric in vanilla_stats:
                    print(f"  {metric}: {vanilla_stats[metric]} (vanilla only)")
                elif metric in evp_stats:
                    print(f"  {metric}: {evp_stats[metric]} (EVP only)")
