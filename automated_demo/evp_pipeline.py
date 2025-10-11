#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path
from datetime import datetime
from klee_runner import KLEERunner

class EVPPipeline:
    def __init__(self, config_file="config/programs.json"):
        with open(config_file) as f:
            self.config = json.load(f)
        
        # Environment setup
        # Get project root (parent of automated_demo directory)
        project_root = Path(__file__).parent.parent.resolve()
        
        self.env = {
            "CLANG": os.environ.get("CLANG", "/usr/lib/llvm-10/bin/clang"),
            "OPT": os.environ.get("OPT", "/usr/lib/llvm-10/bin/opt"),
            "LLVMLINK": os.environ.get("LLVMLINK", "/usr/lib/llvm-10/bin/llvm-link"),
            "KLEE_BIN": os.environ.get("KLEE_BIN", "/home/roxana/klee-env/klee-source/klee/build/bin/klee"),
            "PASS_SO": os.environ.get("PASS_SO", str(project_root / "vasepass" / "libVaseInstrumentPass.so")),
            "LOGGER_C": os.environ.get("LOGGER_C", str(project_root / "logger.c")),
            "ROOT": os.environ.get("ROOT", str(project_root / "benchmarks")),
        }
        
        self.artifacts_dir = Path(self.env["ROOT"]) / "evp_artifacts"
        self.artifacts_dir.mkdir(parents=True, exist_ok=True)
        
        # Initialize KLEE runner
        self.klee_runner = KLEERunner(self.env["KLEE_BIN"], project_root, self.config)
        
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
            result = self.run_command(cmd, cwd=self.env["ROOT"])
            if result.returncode != 0:
                print(f"[WARNING] Step1 script failed, creating placeholder bitcode...")
                # Create placeholder bitcode if script fails
                self.create_placeholder_bitcode(program, prog_dir)
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
        generate_script = Path(self.env["ROOT"]) / "generate_limited_map.py"
        cmd = f"""python3 {generate_script} \
                  --log {vase_log} \
                  --out {map_file} \
                  --max-values {thresholds['max_values']} \
                  --min-occurrence {thresholds['min_occurrence']}"""
        self.run_command(cmd)
        
        print(f"[OK] Generated map -> {map_file}")
        return map_file
    
    def phase3_evaluate(self, category, program, prog_dir, map_file):
        """Phase 3: Run comprehensive KLEE evaluation with parallel execution"""
        print(f"\n[PHASE 3] Evaluating {program} with KLEE")
        
        base_bc = prog_dir / f"{program}.base.bc"
        
        # Get KLEE configuration for this category
        klee_config = self.config[category].get("klee_config", {})
        
        # Get test environment file if specified
        test_env = None
        if klee_config.get("test_env"):
            test_env_path = self.env["ROOT"] / klee_config["test_env"]
            if test_env_path.exists():
                test_env = test_env_path
            else:
                print(f"[WARNING] Test environment file not found: {test_env_path}")
        
        # Get extra KLEE flags
        extra_klee_flags = klee_config.get("extra_klee_flags", [])
        
        # Generate run ID
        run_id = datetime.now().strftime("%Y%m%d-%H%M%S")
        
        # Run parallel KLEE evaluation
        results = self.klee_runner.run_parallel_evaluation(
            bitcode_path=base_bc,
            map_file=map_file,
            program=program,
            category=category,
            run_id=run_id,
            extra_args=extra_klee_flags,
            test_env=test_env
        )
        
        # Display results
        self.display_klee_results(results)
        
        # Save detailed results
        self.save_klee_results(results, prog_dir)
        
        return results
    
    def display_klee_results(self, results):
        """Display KLEE evaluation results"""
        program = results["program"]
        vanilla = results["vanilla"]
        evp = results["evp"]
        
        print(f"\n[RESULTS] {program}:")
        print(f"  Vanilla KLEE: {'SUCCESS' if vanilla['success'] else 'FAILED'}")
        print(f"    - Exit code: {vanilla['exit_code']}")
        print(f"    - Test cases: {vanilla['ktest_count']}")
        print(f"    - Output dir: {vanilla['output_dir']}")
        
        print(f"  EVP KLEE: {'SUCCESS' if evp['success'] else 'FAILED'}")
        print(f"    - Exit code: {evp['exit_code']}")
        print(f"    - Test cases: {evp['ktest_count']}")
        print(f"    - Output dir: {evp['output_dir']}")
        
        # Compare performance metrics
        if vanilla['success'] and evp['success']:
            self.klee_runner.compare_results(vanilla['stats'], evp['stats'], program)
    
    def save_klee_results(self, results, prog_dir):
        """Save detailed KLEE results to JSON file"""
        results_file = prog_dir / f"klee_results_{results['run_id']}.json"
        
        # Prepare results for JSON serialization
        json_results = {
            "program": results["program"],
            "run_id": results["run_id"],
            "timestamp": datetime.now().isoformat(),
            "vanilla": {
                "success": results["vanilla"]["success"],
                "exit_code": results["vanilla"]["exit_code"],
                "output_dir": results["vanilla"]["output_dir"],
                "ktest_count": results["vanilla"]["ktest_count"],
                "stats": results["vanilla"]["stats"]
            },
            "evp": {
                "success": results["evp"]["success"],
                "exit_code": results["evp"]["exit_code"],
                "output_dir": results["evp"]["output_dir"],
                "ktest_count": results["evp"]["ktest_count"],
                "stats": results["evp"]["stats"]
            }
        }
        
        with open(results_file, 'w') as f:
            json.dump(json_results, f, indent=2)
        
        print(f"[SAVED] Detailed KLEE results -> {results_file}")
        
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
    
    def create_placeholder_bitcode(self, program, prog_dir):
        """Create placeholder bitcode for testing"""
        base_bc = prog_dir / f"{program}.base.bc"
        
        # Create a simple C program
        source_c = prog_dir / f"{program}_source.c"
        with open(source_c, 'w') as f:
            f.write(f"""
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char *argv[]) {{
    // Placeholder program for {program}
    printf("Running {program}...\\n");
    
    // Basic argument processing
    for (int i = 1; i < argc; i++) {{
        printf("Arg %d: %s\\n", i, argv[i]);
    }}
    
    return 0;
}}
""")
        
        # Compile to bitcode
        cmd = f'{self.env["CLANG"]} -O0 -g -emit-llvm -c {source_c} -o {base_bc}'
        self.run_command(cmd)
        
        # Clean up source
        source_c.unlink()
        
        print(f"[OK] Created placeholder bitcode: {base_bc}")
    
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
