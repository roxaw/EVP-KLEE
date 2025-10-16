#!/usr/bin/env python3
import argparse
import json
import os
import re
from collections import defaultdict

def parse_args():
    p = argparse.ArgumentParser(description="Build VASE limited-valued map from vase_value_log.txt")
    p.add_argument("--log", default="vase_value_log.txt",
                   help="Input log file produced by instrumentation (default: vase_value_log.txt)")
    p.add_argument("--out", default="limitedValuedMap.json",
                   help="Output JSON map (default: limitedValuedMap.json)")
    p.add_argument("--max-values", type=int, default=8,
                   help="Max distinct values for a var at a site to be considered limited (default: 10)")
    p.add_argument("--min-occurrence", type=int, default=3,
                   help="Minimum times a var must be observed at a site (across runs) (default: 2)")
    p.add_argument("--no-branchless", action="store_true",
                   help="Do NOT emit base keys loc:N aggregated across branches (by default branchless keys are emitted)")
    return p.parse_args()

def main():
    args = parse_args()
    log_file = args.log
    out_file = args.out
    MAX_LIMITED_VALUES = args.max_values
    MIN_OCCURRENCE = args.min_occurrence
    keep_branchless = not args.no_branchless

    if not os.path.exists(log_file):
        print(f"❌ Log file not found: {log_file}")
        return

    # value_map[loc][branch][var] = set(values)
    value_map = defaultdict(lambda: defaultdict(lambda: defaultdict(set)))
    # occ_count[loc][branch][var] = count
    occ_count = defaultdict(lambda: defaultdict(lambda: defaultdict(int)))

    line_re = re.compile(r'^loc:(-?\d+):branch:(-?\d+)$')

    total_lines = 0
    good_lines = 0
    skipped_neg_branch = 0
    skipped_malformed = 0

    with open(log_file, "r", encoding="utf-8", errors="ignore") as f:
        for raw in f:
            total_lines += 1
            line = raw.strip()
            if not line:
                continue
            # Expect "loc:<n>:branch:<b>\t<var>:<val>"
            if "\t" not in line:
                skipped_malformed += 1
                continue

            loc_part, var_part = line.split("\t", 1)
            m = line_re.match(loc_part)
            if not m:
                skipped_malformed += 1
                continue

            loc = m.group(1)
            branch = m.group(2)
            try:
                b = int(branch)
            except Exception:
                skipped_malformed += 1
                continue

            # negative branches (e.g., function entry) are not decision points
            if b < 0:
                skipped_neg_branch += 1
                continue

            if ":" not in var_part:
                skipped_malformed += 1
                continue

            var_name, var_value = var_part.split(":", 1)
            var_name = var_name.strip()
            var_value = var_value.strip()
            if not var_name:
                skipped_malformed += 1
                continue

            value_map[loc][branch][var_name].add(var_value)
            occ_count[loc][branch][var_name] += 1
            good_lines += 1

    # Build output JSON: include branch-qualified keys and base (loc:N) keys by default
    output = {}

    def sorted_values(values):
        vals = list(values)
        try:
            vals.sort(key=lambda x: int(x))
        except Exception:
            vals.sort()
        return vals

    # 1) Branch-qualified
    for loc, branches in value_map.items():
        for branch, vars in branches.items():
            limited_vars = {}
            for var, values in vars.items():
                if occ_count[loc][branch][var] < MIN_OCCURRENCE:
                    continue
                if len(values) <= MAX_LIMITED_VALUES:
                    limited_vars[var] = [{"type": 0, "value": v} for v in sorted_values(values)]
            if limited_vars:
                output[f"loc:{loc}:branch:{branch}"] = limited_vars

    # 2) Base (branchless): union values across branches, sum occurrences
    if keep_branchless:
        for loc, branches in value_map.items():
            union_vals = defaultdict(set)
            union_occ = defaultdict(int)
            for branch, vars in branches.items():
                for var, values in vars.items():
                    union_vals[var].update(values)
                    union_occ[var] += occ_count[loc][branch][var]
            limited_vars = {}
            for var, values in union_vals.items():
                if union_occ[var] < MIN_OCCURRENCE:
                    continue
                if len(values) <= MAX_LIMITED_VALUES:
                    limited_vars[var] = [{"type": 0, "value": v} for v in sorted_values(values)]
            if limited_vars:
                output[f"loc:{loc}"] = limited_vars

    with open(out_file, "w", encoding="utf-8") as out:
        json.dump(output, out, indent=2)

    # Summary
    print(f"✅ Done. Written limited-valued map to {out_file}")
    print(f"   lines: total={total_lines} good={good_lines} malformed={skipped_malformed} skipped_neg_branch={skipped_neg_branch}")
    print(f"   entries: {len(output)}")
    print(f"   thresholds: MIN_OCCURRENCE={MIN_OCCURRENCE} MAX_LIMITED_VALUES={MAX_LIMITED_VALUES} branchless={'on' if keep_branchless else 'off'}")

if __name__ == "__main__":
    main()
