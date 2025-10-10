#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path
from datetime import datetime

class EVPPipeline:
    def __init__(self, config_file="config/programs.json"):
        with open(config_file) as f:
            self.config = json.load(f)
        
        # Environment setup
        self.env = {
            "CLANG": os.environ.get("CLANG", "/usr/lib/llvm-10/bin/clang"),
            "OPT": os.environ.get("OPT", "/usr/lib/llvm-10/bin/opt"),
            "LLVMLINK": os.environ.get("LLVMLINK", "/usr/lib/llvm-10/bin/llvm-link"),
            "KLEE_BIN": os.environ.get("KLEE_BIN", "/home/roxana/klee-env/klee-source/klee/build/bin/klee"),
            "PASS_SO": os.environ.get("PASS_SO", "/home/roxana/VASE-klee/vasepass/libVaseInstrumentPass.so"),
            "LOGGER_C": os.environ.get("LOGGER_C", "/home/roxana/VASE-klee/logger.c"),
            "ROOT": os.environ.get("ROOT", "/home/roxana/Downloads/klee-mm-benchmarks"),
        }
        
        self.artifacts_dir = Path(self.env["ROOT"]) / "evp_artifacts"
        self.artifacts_dir.mkdir(exist_ok=True)
        
    def run_command(self, cmd, cwd=None):
        """Execute command and return output"""
        result = subprocess.run(cmd, shell=True, cwd=cwd, 
                              capture_output=True, text=True)
        if result.returncode != 0:
            print(f"[ERROR] Command failed: {cmd}")
            print(result.stderr)
        return result
    
    def phase1_instrument(self, category, program):
        """Phase 1: Extract bitcode and instrument"""
        print(f"\n[PHASE 1] Instrumenting {program} from {category}")
        
        cfg = self.config[category]
        prog_dir = self.artifacts_dir / category / program
        prog_dir.mkdir(parents=True, exist_ok=True)
        
        # For coreutils, use existing script
        if category == "coreutils":
            cmd = f"./evp_step1_collect.sh {program}"
            self.run_command(cmd, cwd=self.env["ROOT"])
            return prog_dir
        
        # For other programs, adapt the process
        base_bc = prog_dir / f"{program}.base.bc"
        
        # Extract/build bitcode based on type
        if cfg["type"] == "library":
            # Build library and extract bitcode from test binary
            build_cmd = cfg["build_cmd"].format(program=program)
            self.run_command(build_cmd)
            # Extract from test driver
            driver_bc = self.compile_driver(cfg["driver"], program)
            base_bc = driver_bc
        else:
            # CLI program - extract from binary
            build_cmd = cfg["build_cmd"].format(program=program)
            self.run_command(build_cmd)
        
        # Instrument
        inst_bc = prog_dir / f"{program}.evpinstr.bc"
        cmd = f'{self.env["OPT"]} -load {self.env["PASS_SO"]} -vase-instrument {base_bc} -o {inst_bc}'
        self.run_command(cmd)
        
        # Link with logger
        logger_bc = prog_dir / "logger.bc"
        cmd = f'{self.env["CLANG"]} -O0 -emit-llvm -c {self.env["LOGGER_C"]} -o {logger_bc}'
        self.run_command(cmd)
        
        final_bc = prog_dir / f"{program}_final.bc"
        cmd = f'{self.env["LLVMLINK"]} {inst_bc} {logger_bc} -o {final_bc}'
        self.run_command(cmd)
        
        # Build executable
        final_exe = prog_dir / f"{program}_final_exe"
        libs = cfg.get("libs", "")
        cmd = f'{self.env["CLANG"]} {final_bc} -o {final_exe} {libs}'
        self.run_command(cmd)
        
        print(f"[OK] Instrumented {program} -> {final_exe}")
        return prog_dir
    
    def phase2_profile(self, category, program, prog_dir):
        """Phase 2: Run tests and collect values"""
        print(f"\n[PHASE 2] Profiling {program}")
        
        cfg = self.config[category]
        vase_log = prog_dir / "vase_value_log.txt"
        
        # Set environment for logging
        env = os.environ.copy()
        env["VASE_LOG"] = str(vase_log)
        env["VASE_DIR"] = str(prog_dir)
        
        # Run tests based on type
        if category == "coreutils":
            cmd = f"./test-harness-generic.sh {program}"
            subprocess.run(cmd, shell=True, env=env, cwd=self.env["ROOT"])
        elif cfg["type"] == "library":
            # Run driver program
            driver_exe = prog_dir / f"{program}_driver"
            subprocess.run(str(driver_exe), env=env)
        else:
            # Run program's test suite
            test_cmd = cfg["test_cmd"].format(program=program)
            subprocess.run(test_cmd, shell=True, env=env)
        
        # Generate map
        thresholds = cfg["thresholds"]
        map_file = prog_dir / "limitedValuedMap.json"
        cmd = f"""python3 generate_limited_map.py \
                  --log {vase_log} \
                  --out {map_file} \
                  --max-values {thresholds['max_values']} \
                  --min-occurrence {thresholds['min_occurrence']}"""
        self.run_command(cmd)
        
        print(f"[OK] Generated map -> {map_file}")
        return map_file
    
    def phase3_evaluate(self, category, program, prog_dir, map_file):
        """Phase 3: Run KLEE evaluation"""
        print(f"\n[PHASE 3] Evaluating {program} with KLEE")
        
        base_bc = prog_dir / f"{program}.base.bc"
        
        # Run vanilla KLEE
        vanilla_out = prog_dir / "klee-out-vanilla"
        cmd = f'{self.env["KLEE_BIN"]} --output-dir={vanilla_out} --max-time=1800 {base_bc}'
        print(f"[RUN] Vanilla KLEE on {program}")
        self.run_command(cmd)
        
        # Run EVP-KLEE
        evp_out = prog_dir / "klee-out-evp"
        cmd = f'{self.env["KLEE_BIN"]} --output-dir={evp_out} --max-time=1800 --evp-map={map_file} {base_bc}'
        print(f"[RUN] EVP-KLEE on {program}")
        self.run_command(cmd)
        
        # Extract and compare stats
        self.compare_results(vanilla_out, evp_out, program)
        
    def compare_results(self, vanilla_dir, evp_dir, program):
        """Compare KLEE results"""
        print(f"\n[RESULTS] {program}:")
        
        # Extract key metrics from info files
        metrics = ["QueryTime", "SolverTime", "WallTime", "NumQueries"]
        
        vanilla_stats = self.parse_klee_stats(vanilla_dir / "info")
        evp_stats = self.parse_klee_stats(evp_dir / "info")
        
        for metric in metrics:
            if metric in vanilla_stats and metric in evp_stats:
                v_val = float(vanilla_stats[metric])
                e_val = float(evp_stats[metric])
                improvement = ((v_val - e_val) / v_val) * 100 if v_val > 0 else 0
                print(f"  {metric}: {improvement:.2f}% improvement")
    
    def parse_klee_stats(self, info_file):
        """Parse KLEE info file for statistics"""
        stats = {}
        if info_file.exists():
            with open(info_file) as f:
                for line in f:
                    if ":" in line:
                        key, val = line.strip().split(":", 1)
                        stats[key.strip()] = val.strip()
        return stats
    
    def compile_driver(self, driver_path, program):
        """Compile driver program for libraries"""
        driver_c = Path(driver_path)
        driver_bc = self.artifacts_dir / f"{program}_driver.bc"
        cmd = f'{self.env["CLANG"]} -emit-llvm -g -O0 -c {driver_c} -o {driver_bc}'
        self.run_command(cmd)
        return driver_bc
    
    def run_batch(self, categories=None):
        """Run full pipeline for all programs"""
        if categories is None:
            categories = list(self.config.keys())
        
        results = []
        for category in categories:
            if category not in self.config:
                print(f"[SKIP] Unknown category: {category}")
                continue
                
            programs = self.config[category]["programs"]
            for program in programs:
                print(f"\n{'='*60}")
                print(f"Processing {program} from {category}")
                print(f"{'='*60}")
                
                try:
                    # Phase 1: Instrument
                    prog_dir = self.phase1_instrument(category, program)
                    
                    # Phase 2: Profile
                    map_file = self.phase2_profile(category, program, prog_dir)
                    
                    # Phase 3: Evaluate
                    self.phase3_evaluate(category, program, prog_dir, map_file)
                    
                    results.append({"program": program, "category": category, "status": "success"})
                except Exception as e:
                    print(f"[ERROR] Failed processing {program}: {e}")
                    results.append({"program": program, "category": category, "status": "failed", "error": str(e)})
        
        # Save results
        self.save_results(results)
        return results
    
    def save_results(self, results):
        """Save batch results to JSON"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        result_file = self.artifacts_dir / f"batch_results_{timestamp}.json"
        with open(result_file, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"\n[SAVED] Results -> {result_file}")

if __name__ == "__main__":
    pipeline = EVPPipeline()
    
    if len(sys.argv) > 1:
        # Run specific category
        pipeline.run_batch([sys.argv[1]])
    else:
        # Run all (start with coreutils for testing)
        pipeline.run_batch(["coreutils"])
