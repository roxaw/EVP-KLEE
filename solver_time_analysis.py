#!/usr/bin/env python3
"""
SolverTime Analysis Script for EVP vs Vanilla KLEE Comparison

This script analyzes the SolverTime performance between EVP and vanilla versions
of KLEE for different programs (sqlite and libxml2). It generates scatter plots
and summary tables showing the improvements achieved by EVP.
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import os
from pathlib import Path
import seaborn as sns

# Set style for better plots
plt.style.use('seaborn-v0_8')
sns.set_palette("husl")

class SolverTimeAnalyzer:
    def __init__(self, base_path):
        self.base_path = Path(base_path)
        self.results = {}
        
    def load_csv_data(self, program_name, evp_path, vanilla_path):
        """Load EVP and vanilla CSV data for a program"""
        try:
            evp_df = pd.read_csv(evp_path)
            vanilla_df = pd.read_csv(vanilla_path)
            
            # Ensure both dataframes have SolverTime column
            if 'SolverTime' not in evp_df.columns or 'SolverTime' not in vanilla_df.columns:
                raise ValueError(f"SolverTime column not found in {program_name} data")
            
            # Filter out rows where SolverTime is 0 or NaN (initial states)
            evp_df = evp_df[evp_df['SolverTime'] > 0].copy()
            vanilla_df = vanilla_df[vanilla_df['SolverTime'] > 0].copy()
            
            return evp_df, vanilla_df
        except Exception as e:
            print(f"Error loading data for {program_name}: {e}")
            return None, None
    
    def calculate_improvements(self, evp_df, vanilla_df, program_name):
        """Calculate various improvement metrics"""
        evp_times = evp_df['SolverTime'].values
        vanilla_times = vanilla_df['SolverTime'].values
        
        # Calculate statistics
        evp_mean = np.mean(evp_times)
        vanilla_mean = np.mean(vanilla_times)
        evp_median = np.median(evp_times)
        vanilla_median = np.median(vanilla_times)
        evp_total = np.sum(evp_times)
        vanilla_total = np.sum(vanilla_times)
        
        # Calculate improvements
        mean_improvement = ((vanilla_mean - evp_mean) / vanilla_mean) * 100
        median_improvement = ((vanilla_median - evp_median) / vanilla_median) * 100
        total_improvement = ((vanilla_total - evp_total) / vanilla_total) * 100
        
        # Calculate speedup ratios
        mean_speedup = vanilla_mean / evp_mean if evp_mean > 0 else 0
        median_speedup = vanilla_median / evp_median if evp_median > 0 else 0
        total_speedup = vanilla_total / evp_total if evp_total > 0 else 0
        
        return {
            'program': program_name,
            'evp_mean': evp_mean,
            'vanilla_mean': vanilla_mean,
            'evp_median': evp_median,
            'vanilla_median': vanilla_median,
            'evp_total': evp_total,
            'vanilla_total': vanilla_total,
            'mean_improvement_pct': mean_improvement,
            'median_improvement_pct': median_improvement,
            'total_improvement_pct': total_improvement,
            'mean_speedup': mean_speedup,
            'median_speedup': median_speedup,
            'total_speedup': total_speedup,
            'evp_samples': len(evp_times),
            'vanilla_samples': len(vanilla_times)
        }
    
    def create_scatter_plot(self, evp_df, vanilla_df, program_name, output_dir):
        """Create scatter plot comparing EVP vs Vanilla SolverTime"""
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))
        
        # Plot 1: Scatter plot of SolverTime over time (instructions)
        evp_df_clean = evp_df[evp_df['Instructions'] > 0]
        vanilla_df_clean = vanilla_df[vanilla_df['Instructions'] > 0]
        
        ax1.scatter(evp_df_clean['Instructions'], evp_df_clean['SolverTime'], 
                   alpha=0.6, label='EVP', s=30, color='blue')
        ax1.scatter(vanilla_df_clean['Instructions'], vanilla_df_clean['SolverTime'], 
                   alpha=0.6, label='Vanilla', s=30, color='red')
        ax1.set_xlabel('Instructions')
        ax1.set_ylabel('SolverTime (ms)')
        ax1.set_title(f'{program_name.upper()}: SolverTime vs Instructions')
        ax1.legend()
        ax1.grid(True, alpha=0.3)
        
        # Plot 2: Direct comparison scatter plot
        min_samples = min(len(evp_df), len(vanilla_df))
        evp_sample = evp_df['SolverTime'].iloc[:min_samples]
        vanilla_sample = vanilla_df['SolverTime'].iloc[:min_samples]
        
        ax2.scatter(vanilla_sample, evp_sample, alpha=0.6, s=30)
        
        # Add diagonal line for reference (y=x)
        max_val = max(vanilla_sample.max(), evp_sample.max())
        ax2.plot([0, max_val], [0, max_val], 'r--', alpha=0.7, label='y=x (no improvement)')
        
        ax2.set_xlabel('Vanilla SolverTime (ms)')
        ax2.set_ylabel('EVP SolverTime (ms)')
        ax2.set_title(f'{program_name.upper()}: EVP vs Vanilla SolverTime')
        ax2.legend()
        ax2.grid(True, alpha=0.3)
        
        # Add improvement text
        evp_mean = evp_sample.mean()
        vanilla_mean = vanilla_sample.mean()
        improvement = ((vanilla_mean - evp_mean) / vanilla_mean) * 100
        ax2.text(0.05, 0.95, f'Mean Improvement: {improvement:.1f}%', 
                transform=ax2.transAxes, bbox=dict(boxstyle="round,pad=0.3", facecolor="lightblue"))
        
        plt.tight_layout()
        plt.savefig(output_dir / f'{program_name}_solver_time_comparison.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def create_box_plot(self, evp_df, vanilla_df, program_name, output_dir):
        """Create box plot comparing distributions"""
        fig, ax = plt.subplots(figsize=(10, 6))
        
        data_to_plot = [evp_df['SolverTime'], vanilla_df['SolverTime']]
        labels = ['EVP', 'Vanilla']
        
        box_plot = ax.boxplot(data_to_plot, labels=labels, patch_artist=True)
        box_plot['boxes'][0].set_facecolor('lightblue')
        box_plot['boxes'][1].set_facecolor('lightcoral')
        
        ax.set_ylabel('SolverTime (ms)')
        ax.set_title(f'{program_name.upper()}: SolverTime Distribution Comparison')
        ax.grid(True, alpha=0.3)
        
        # Add statistics text
        evp_median = evp_df['SolverTime'].median()
        vanilla_median = vanilla_df['SolverTime'].median()
        improvement = ((vanilla_median - evp_median) / vanilla_median) * 100
        
        ax.text(0.02, 0.98, f'Median Improvement: {improvement:.1f}%', 
                transform=ax.transAxes, bbox=dict(boxstyle="round,pad=0.3", facecolor="lightgreen"))
        
        plt.tight_layout()
        plt.savefig(output_dir / f'{program_name}_solver_time_distribution.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def analyze_program(self, program_name, evp_path, vanilla_path, output_dir):
        """Analyze a single program's SolverTime performance"""
        print(f"Analyzing {program_name}...")
        
        # Load data
        evp_df, vanilla_df = self.load_csv_data(program_name, evp_path, vanilla_path)
        if evp_df is None or vanilla_df is None:
            return None
        
        # Calculate improvements
        improvements = self.calculate_improvements(evp_df, vanilla_df, program_name)
        
        # Create visualizations
        self.create_scatter_plot(evp_df, vanilla_df, program_name, output_dir)
        self.create_box_plot(evp_df, vanilla_df, program_name, output_dir)
        
        return improvements
    
    def create_summary_table(self, results, output_dir):
        """Create a comprehensive summary table"""
        if not results:
            print("No results to summarize")
            return
        
        # Create DataFrame for summary
        summary_data = []
        for result in results:
            summary_data.append({
                'Program': result['program'].upper(),
                'EVP Mean (ms)': f"{result['evp_mean']:.2f}",
                'Vanilla Mean (ms)': f"{result['vanilla_mean']:.2f}",
                'Mean Improvement (%)': f"{result['mean_improvement_pct']:.2f}",
                'Mean Speedup': f"{result['mean_speedup']:.2f}x",
                'EVP Median (ms)': f"{result['evp_median']:.2f}",
                'Vanilla Median (ms)': f"{result['vanilla_median']:.2f}",
                'Median Improvement (%)': f"{result['median_improvement_pct']:.2f}",
                'Median Speedup': f"{result['median_speedup']:.2f}x",
                'EVP Total (ms)': f"{result['evp_total']:.2f}",
                'Vanilla Total (ms)': f"{result['vanilla_total']:.2f}",
                'Total Improvement (%)': f"{result['total_improvement_pct']:.2f}",
                'Total Speedup': f"{result['total_speedup']:.2f}x",
                'EVP Samples': result['evp_samples'],
                'Vanilla Samples': result['vanilla_samples']
            })
        
        summary_df = pd.DataFrame(summary_data)
        
        # Save to CSV
        summary_df.to_csv(output_dir / 'solver_time_summary.csv', index=False)
        
        # Create a formatted table plot
        fig, ax = plt.subplots(figsize=(16, 8))
        ax.axis('tight')
        ax.axis('off')
        
        # Create table
        table = ax.table(cellText=summary_df.values,
                        colLabels=summary_df.columns,
                        cellLoc='center',
                        loc='center',
                        bbox=[0, 0, 1, 1])
        
        table.auto_set_font_size(False)
        table.set_fontsize(9)
        table.scale(1.2, 2)
        
        # Style the table
        for i in range(len(summary_df.columns)):
            table[(0, i)].set_facecolor('#4CAF50')
            table[(0, i)].set_text_props(weight='bold', color='white')
        
        plt.title('SolverTime Performance Comparison: EVP vs Vanilla KLEE', 
                 fontsize=16, fontweight='bold', pad=20)
        plt.savefig(output_dir / 'solver_time_summary_table.png', dpi=300, bbox_inches='tight')
        plt.close()
        
        # Print summary to console
        print("\n" + "="*80)
        print("SOLVER TIME PERFORMANCE SUMMARY")
        print("="*80)
        print(summary_df.to_string(index=False))
        print("="*80)
        
        return summary_df
    
    def run_analysis(self):
        """Run the complete analysis"""
        # Define program configurations
        programs = {
            'sqlite': {
                'evp_path': self.base_path / 'sqlite-tmp' / 'klee-evp-stats' / 'sqlite-stats-evp.csv',
                'vanilla_path': self.base_path / 'sqlite-tmp' / 'klee-vanilla-stats' / 'sqlite-stats-vanilla.csv'
            },
            'libxml2': {
                'evp_path': self.base_path / 'libXML2-tmp' / 'libXML2' / 'EVP-klee-output' / 'libxml2-stats-evp.csv',
                'vanilla_path': self.base_path / 'libXML2-tmp' / 'libXML2' / 'vanilla-klee-output' / 'libxml2-stats-vanilla.csv'
            }
        }
        
        # Create output directory
        output_dir = self.base_path / 'solver_time_analysis_results'
        output_dir.mkdir(exist_ok=True)
        
        print("Starting SolverTime Analysis...")
        print(f"Output directory: {output_dir}")
        
        results = []
        
        # Analyze each program
        for program_name, paths in programs.items():
            if paths['evp_path'].exists() and paths['vanilla_path'].exists():
                result = self.analyze_program(program_name, paths['evp_path'], paths['vanilla_path'], output_dir)
                if result:
                    results.append(result)
                    print(f"✓ {program_name.upper()} analysis completed")
                else:
                    print(f"✗ {program_name.upper()} analysis failed")
            else:
                print(f"✗ Files not found for {program_name.upper()}")
                print(f"  EVP: {paths['evp_path']} (exists: {paths['evp_path'].exists()})")
                print(f"  Vanilla: {paths['vanilla_path']} (exists: {paths['vanilla_path'].exists()})")
        
        # Create summary table
        if results:
            summary_df = self.create_summary_table(results, output_dir)
            print(f"\nAnalysis complete! Results saved to: {output_dir}")
            return summary_df
        else:
            print("No successful analyses completed.")
            return None

def main():
    """Main function"""
    # Set the base path to the temp_results directory
    base_path = Path("/home/roxana/VASE-klee/EVP-KLEE/results/temp_results")
    
    # Create analyzer and run analysis
    analyzer = SolverTimeAnalyzer(base_path)
    summary = analyzer.run_analysis()
    
    if summary is not None:
        print("\nAnalysis completed successfully!")
        print("Generated files:")
        print("- solver_time_summary.csv")
        print("- solver_time_summary_table.png")
        print("- {program}_solver_time_comparison.png (scatter plots)")
        print("- {program}_solver_time_distribution.png (box plots)")

if __name__ == "__main__":
    main()
