#!/usr/bin/env python3
"""
EVP-KLEE Coreutils Performance Analysis Script

This script analyzes SolverTime improvements between EVP and vanilla KLEE
for each coreutils program, generating individual comparison plots and
a comprehensive summary table.
"""

import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
import numpy as np

# Set up plotting style
plt.style.use('seaborn-v0_8')
sns.set_palette("husl")

def analyze_program_performance(program_dir, program_name):
    """
    Analyze SolverTime performance for a single program.
    
    Args:
        program_dir (Path): Path to the program directory
        program_name (str): Name of the program
    
    Returns:
        dict: Analysis results including improvement percentage
    """
    evp_file = program_dir / f"{program_name}-stats-evp.csv"
    vanilla_file = program_dir / f"{program_name}-stats-vanilla.csv"
    
    if not evp_file.exists() or not vanilla_file.exists():
        print(f"⚠️  Missing files for {program_name}")
        return None
    
    try:
        # Read CSV files
        evp_df = pd.read_csv(evp_file)
        vanilla_df = pd.read_csv(vanilla_file)
        
        # Extract SolverTime data
        evp_solver_times = evp_df['SolverTime'].values
        vanilla_solver_times = vanilla_df['SolverTime'].values
        
        # Calculate statistics
        evp_mean = np.mean(evp_solver_times)
        vanilla_mean = np.mean(vanilla_solver_times)
        
        # Calculate percentage improvement
        if vanilla_mean > 0:
            improvement_pct = ((vanilla_mean - evp_mean) / vanilla_mean) * 100
        else:
            improvement_pct = 0
        
        # Create scatter plot
        plt.figure(figsize=(10, 6))
        
        # Create data for scatter plot
        evp_indices = np.arange(len(evp_solver_times))
        vanilla_indices = np.arange(len(vanilla_solver_times))
        
        plt.scatter(evp_indices, evp_solver_times, alpha=0.7, s=50, 
                   label=f'EVP (mean: {evp_mean:.0f}s)', color='blue')
        plt.scatter(vanilla_indices, vanilla_solver_times, alpha=0.7, s=50, 
                   label=f'Vanilla (mean: {vanilla_mean:.0f}s)', color='red')
        
        plt.xlabel('Sample Index')
        plt.ylabel('SolverTime (seconds)')
        plt.title(f'{program_name.upper()} - SolverTime Comparison\n'
                 f'Improvement: {improvement_pct:.1f}%')
        plt.legend()
        plt.grid(True, alpha=0.3)
        
        # Save plot
        plot_path = program_dir / f"{program_name}_solver_time_comparison.png"
        plt.savefig(plot_path, dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"✅ {program_name}: {improvement_pct:.1f}% improvement")
        
        return {
            'program': program_name,
            'evp_mean': evp_mean,
            'vanilla_mean': vanilla_mean,
            'improvement_pct': improvement_pct,
            'evp_samples': len(evp_solver_times),
            'vanilla_samples': len(vanilla_solver_times)
        }
        
    except Exception as e:
        print(f"❌ Error analyzing {program_name}: {e}")
        return None

def main():
    """Main analysis function."""
    # Set up paths
    base_dir = Path("/home/roxana/VASE-klee/EVP-KLEE/results/temp_results")
    coreutils_dir = base_dir / "coreutils-tmp"
    
    if not coreutils_dir.exists():
        print(f"❌ Directory not found: {coreutils_dir}")
        return
    
    print("🔍 Analyzing Coreutils Performance...")
    print("=" * 50)
    
    # Get all program directories
    program_dirs = [d for d in coreutils_dir.iterdir() if d.is_dir()]
    program_dirs.sort()
    
    results = []
    
    # Analyze each program
    for program_dir in program_dirs:
        program_name = program_dir.name
        result = analyze_program_performance(program_dir, program_name)
        if result:
            results.append(result)
    
    if not results:
        print("❌ No valid results found!")
        return
    
    # Create summary table
    print("\n📊 Creating Summary Table...")
    print("=" * 50)
    
    summary_df = pd.DataFrame(results)
    summary_df = summary_df.sort_values('improvement_pct', ascending=False)
    
    # Save summary table
    summary_path = coreutils_dir / "solver_time_improvement_summary.csv"
    summary_df.to_csv(summary_path, index=False)
    
    # Display summary
    print("\n📈 SolverTime Improvement Summary:")
    print("-" * 80)
    print(f"{'Program':<12} {'EVP Mean (s)':<12} {'Vanilla Mean (s)':<15} {'Improvement %':<12} {'Samples':<10}")
    print("-" * 80)
    
    for _, row in summary_df.iterrows():
        print(f"{row['program']:<12} {row['evp_mean']:<12.0f} {row['vanilla_mean']:<15.0f} "
              f"{row['improvement_pct']:<12.1f} {row['evp_samples']}/{row['vanilla_samples']:<8}")
    
    # Calculate overall statistics
    avg_improvement = summary_df['improvement_pct'].mean()
    max_improvement = summary_df['improvement_pct'].max()
    min_improvement = summary_df['improvement_pct'].min()
    
    print("-" * 80)
    print(f"Average Improvement: {avg_improvement:.1f}%")
    print(f"Best Improvement: {max_improvement:.1f}% ({summary_df.loc[summary_df['improvement_pct'].idxmax(), 'program']})")
    print(f"Worst Improvement: {min_improvement:.1f}% ({summary_df.loc[summary_df['improvement_pct'].idxmin(), 'program']})")
    
    print(f"\n✅ Analysis complete!")
    print(f"📁 Individual plots saved in each program directory")
    print(f"📊 Summary table saved: {summary_path}")
    
    # Create a summary visualization
    plt.figure(figsize=(12, 8))
    bars = plt.bar(summary_df['program'], summary_df['improvement_pct'], 
                   color=['green' if x > 0 else 'red' for x in summary_df['improvement_pct']])
    plt.xlabel('Program')
    plt.ylabel('SolverTime Improvement (%)')
    plt.title('EVP vs Vanilla KLEE - SolverTime Improvement by Program')
    plt.xticks(rotation=45)
    plt.grid(True, alpha=0.3)
    
    # Add value labels on bars
    for bar, value in zip(bars, summary_df['improvement_pct']):
        plt.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5, 
                f'{value:.1f}%', ha='center', va='bottom')
    
    plt.tight_layout()
    summary_plot_path = coreutils_dir / "overall_improvement_summary.png"
    plt.savefig(summary_plot_path, dpi=300, bbox_inches='tight')
    plt.close()
    
    print(f"📈 Overall summary plot saved: {summary_plot_path}")

if __name__ == "__main__":
    main()
