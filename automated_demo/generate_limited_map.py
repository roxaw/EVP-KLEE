#!/usr/bin/env python3
"""
Generate limited value map from VASE log file.
This script processes the VASE value log and creates a map of limited values.
"""

import json
import argparse
from collections import defaultdict, Counter
from pathlib import Path

def parse_vase_log(log_file):
    """Parse VASE log file and extract value occurrences."""
    value_counts = defaultdict(int)
    
    if not Path(log_file).exists():
        print(f"Warning: Log file {log_file} does not exist. Creating empty map.")
        return value_counts
    
    with open(log_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#'):
                # Simple parsing - assumes one value per line
                value_counts[line] += 1
    
    return value_counts

def generate_limited_map(value_counts, max_values=5, min_occurrence=3):
    """Generate limited value map based on thresholds."""
    limited_map = {}
    
    # Filter values by occurrence threshold
    filtered_values = {k: v for k, v in value_counts.items() if v >= min_occurrence}
    
    # Sort by occurrence count (descending) and take top max_values
    sorted_values = sorted(filtered_values.items(), key=lambda x: x[1], reverse=True)
    
    for i, (value, count) in enumerate(sorted_values[:max_values]):
        limited_map[value] = {
            "occurrence_count": count,
            "priority": i + 1
        }
    
    return limited_map

def main():
    parser = argparse.ArgumentParser(description='Generate limited value map from VASE log')
    parser.add_argument('--log', required=True, help='VASE log file path')
    parser.add_argument('--out', required=True, help='Output map file path')
    parser.add_argument('--max-values', type=int, default=5, help='Maximum number of values to include')
    parser.add_argument('--min-occurrence', type=int, default=3, help='Minimum occurrence count')
    
    args = parser.parse_args()
    
    # Parse log file
    value_counts = parse_vase_log(args.log)
    
    # Generate limited map
    limited_map = generate_limited_map(
        value_counts, 
        args.max_values, 
        args.min_occurrence
    )
    
    # Write output
    output_path = Path(args.out)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_path, 'w') as f:
        json.dump(limited_map, f, indent=2)
    
    print(f"Generated limited map with {len(limited_map)} values")
    print(f"Output saved to: {output_path}")

if __name__ == "__main__":
    main()
