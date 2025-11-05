import pandas as pd
import numpy as np
import os
import glob
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

def load_and_process_data():
    """Load all CSV files and extract key statistics"""
    
    programs = ['cp', 'chmod', 'mv', 'du', 'ln', 'shred', 'touch', 'libxml2']
    variants = ['evp', 'vanilla']
    
    # Get the base directory (assuming script is in scripts/ directory)
    script_dir = Path(__file__).parent
    base_dir = script_dir.parent  # Go up to EVP-KLEE directory
    temp_results_dir = base_dir / 'results' / 'temp_results'
    
    all_stats = []
    
    # Coreutils programs are in coreutils-tmp/{program}/ directory
    coreutils_programs = ['cp', 'chmod', 'mv', 'du', 'ln', 'shred', 'touch']
    
    for program in programs:
        for variant in variants:
            # Determine the file path based on program type
            if program in coreutils_programs:
                # Coreutils programs: temp_results/coreutils-tmp/{program}/{program}-stats-{variant}.csv
                filepath = temp_results_dir / 'coreutils-tmp' / program / f"{program}-stats-{variant}.csv"
            elif program == 'libxml2':
                # libxml2: temp_results/libXML2-tmp/libXML2/{variant}-klee-output/libxml2-stats-{variant}.csv
                if variant == 'evp':
                    filepath = temp_results_dir / 'libXML2-tmp' / 'libXML2' / 'EVP-klee-output' / f"libxml2-stats-{variant}.csv"
                else:  # vanilla
                    filepath = temp_results_dir / 'libXML2-tmp' / 'libXML2' / 'vanilla-klee-output' / f"libxml2-stats-{variant}.csv"
            else:
                # Fallback: try in current directory (for backward compatibility)
                filepath = Path(f"{program}-stats-{variant}.csv")
            
            if filepath.exists():
                print(f"Processing {filepath}...")
                df = pd.read_csv(filepath)
                
                # Get final row statistics (end of execution)
                final_stats = df.iloc[-1].to_dict()
                
                # Get max coverage achieved
                max_coverage = df['CoveredInstructions'].max()
                
                # Calculate some derived metrics
                stats = {
                    'Program': program,
                    'Variant': variant,
                    'FinalQueryTime': final_stats['QueryTime'],
                    'FinalSolverTime': final_stats['SolverTime'],
                    'FinalCexCacheTime': final_stats['CexCacheTime'],
                    'TotalQueries': final_stats['NumQueries'],
                    'TotalQueryConstructs': final_stats['NumQueryConstructs'],
                    'MaxCoverage': max_coverage,
                    'FinalCoverage': final_stats['CoveredInstructions'],
                    'UncoveredInstructions': final_stats['UncoveredInstructions'],
                    'TotalInstructions': final_stats['CoveredInstructions'] + final_stats['UncoveredInstructions'],
                    'WallTime': final_stats['WallTime'],
                    'UserTime': final_stats['UserTime'],
                    'NumStates': final_stats['NumStates'],
                    'MemoryUsage': final_stats['MallocUsage'] / (1024 * 1024),  # Convert to MB
                    'FullBranches': final_stats['FullBranches'],
                    'PartialBranches': final_stats['PartialBranches']
                }
                
                # For EVP, try to extract overhead information from early rows
                if variant == 'evp' and len(df) > 1:
                    # Estimate instrumentation/profiling overhead from initial rows
                    if len(df) > 3:
                        stats['InstrumentTime'] = df.iloc[1]['WallTime'] / 1000  # First non-zero row
                        stats['ProfileTime'] = (df.iloc[2]['WallTime'] - df.iloc[1]['WallTime']) / 1000
                        stats['AnalyzeTime'] = (df.iloc[3]['WallTime'] - df.iloc[2]['WallTime']) / 1000
                    else:
                        stats['InstrumentTime'] = 0
                        stats['ProfileTime'] = 0
                        stats['AnalyzeTime'] = 0
                
                all_stats.append(stats)
            else:
                print(f"Warning: {filepath} not found")
    
    return pd.DataFrame(all_stats)

def prepare_rq1_analysis(df):
    """RQ1: How effectively does EVP reduce constraint solving time?"""
    
    rq1_results = []
    
    for program in df['Program'].unique():
        program_data = df[df['Program'] == program]
        
        vanilla_data = program_data[program_data['Variant'] == 'vanilla']
        evp_data = program_data[program_data['Variant'] == 'evp']
        
        if not vanilla_data.empty and not evp_data.empty:
            vanilla_row = vanilla_data.iloc[0]
            evp_row = evp_data.iloc[0]
            
            # QueryTime comparison (COMMENTED OUT)
            # rq1_results.append({
            #     'Program': program,
            #     'Metric': 'QueryTime (s)',
            #     'Vanilla': round(vanilla_row['FinalQueryTime'] / 1000, 2),
            #     'EVP': round(evp_row['FinalQueryTime'] / 1000, 2),
            #     'Improvement (%)': round(((vanilla_row['FinalQueryTime'] - evp_row['FinalQueryTime']) / 
            #                              vanilla_row['FinalQueryTime'] * 100) if vanilla_row['FinalQueryTime'] > 0 else 0, 1)
            # })
            
            # NumQueries comparison
            rq1_results.append({
                'Program': program,
                'Metric': 'NumQueries',
                'Vanilla': int(vanilla_row['TotalQueries']),
                'EVP': int(evp_row['TotalQueries']),
                'Improvement (%)': round(((vanilla_row['TotalQueries'] - evp_row['TotalQueries']) / 
                                         vanilla_row['TotalQueries'] * 100) if vanilla_row['TotalQueries'] > 0 else 0, 1)
            })
            
            # SolverTime comparison
            rq1_results.append({
                'Program': program,
                'Metric': 'SolverTime (s)',
                'Vanilla': round(vanilla_row['FinalSolverTime'] / 1000, 2),
                'EVP': round(evp_row['FinalSolverTime'] / 1000, 2),
                'Improvement (%)': round(((vanilla_row['FinalSolverTime'] - evp_row['FinalSolverTime']) / 
                                         vanilla_row['FinalSolverTime'] * 100) if vanilla_row['FinalSolverTime'] > 0 else 0, 1)
            })
            
            # UserTime comparison
            rq1_results.append({
                'Program': program,
                'Metric': 'UserTime (s)',
                'Vanilla': round(vanilla_row['UserTime'] / 1000, 2),
                'EVP': round(evp_row['UserTime'] / 1000, 2),
                'Improvement (%)': round(((vanilla_row['UserTime'] - evp_row['UserTime']) / 
                                         vanilla_row['UserTime'] * 100) if vanilla_row['UserTime'] > 0 else 0, 1)
            })
            
            # Coverage (should be maintained)
            rq1_results.append({
                'Program': program,
                'Metric': 'Coverage (inst)',
                'Vanilla': int(vanilla_row['FinalCoverage']),
                'EVP': int(evp_row['FinalCoverage']),
                'Improvement (%)': round(((evp_row['FinalCoverage'] - vanilla_row['FinalCoverage']) / 
                                         vanilla_row['FinalCoverage'] * 100) if vanilla_row['FinalCoverage'] > 0 else 0, 1)
            })
    
    return pd.DataFrame(rq1_results)

def prepare_rq2_analysis(df):
    """RQ2: What is the overhead introduced by EVP's profiling and analysis phases?"""
    
    rq2_results = []
    
    evp_data = df[df['Variant'] == 'evp']
    
    for _, row in evp_data.iterrows():
        overhead_data = {
            'Program': row['Program'],
            'Instrument (s)': round(row.get('InstrumentTime', 0), 1),
            'Profile (s)': round(row.get('ProfileTime', 0), 1),
            'Analyze (s)': round(row.get('AnalyzeTime', 0), 1)
        }
        
        # Calculate total overhead
        total_overhead = (overhead_data['Instrument (s)'] + 
                         overhead_data['Profile (s)'] + 
                         overhead_data['Analyze (s)'])
        overhead_data['Total (s)'] = round(total_overhead, 1)
        
        # Calculate percentage of total wall time
        if row['WallTime'] > 0:
            overhead_pct = (total_overhead * 1000 / row['WallTime']) * 100
            overhead_data['Overhead (%)'] = round(overhead_pct, 1)
        else:
            overhead_data['Overhead (%)'] = 0
        
        # Add memory overhead
        overhead_data['Memory (MB)'] = round(row['MemoryUsage'], 1)
        
        rq2_results.append(overhead_data)
    
    return pd.DataFrame(rq2_results)

def prepare_rq3_analysis(df):
    """RQ3: How does EVP's performance vary across different program characteristics?"""
    
    rq3_results = []
    
    for program in df['Program'].unique():
        program_data = df[df['Program'] == program]
        
        vanilla_data = program_data[program_data['Variant'] == 'vanilla']
        evp_data = program_data[program_data['Variant'] == 'evp']
        
        if not vanilla_data.empty and not evp_data.empty:
            vanilla_row = vanilla_data.iloc[0]
            evp_row = evp_data.iloc[0]
            
            characteristics = {
                'Program': program,
                'Instructions': int(vanilla_row['TotalInstructions']),
                'Branches': int(vanilla_row['FullBranches'] + vanilla_row['PartialBranches']),
                'States': int(vanilla_row['NumStates']),
                # 'QueryTime Reduction (%)': round(((vanilla_row['FinalQueryTime'] - evp_row['FinalQueryTime']) / 
                #                                   vanilla_row['FinalQueryTime'] * 100) if vanilla_row['FinalQueryTime'] > 0 else 0, 1),  # COMMENTED OUT
                'NumQueries Reduction (%)': round(((vanilla_row['TotalQueries'] - evp_row['TotalQueries']) / 
                                                   vanilla_row['TotalQueries'] * 100) if vanilla_row['TotalQueries'] > 0 else 0, 1),
                'SolverTime Reduction (%)': round(((vanilla_row['FinalSolverTime'] - evp_row['FinalSolverTime']) / 
                                                   vanilla_row['FinalSolverTime'] * 100) if vanilla_row['FinalSolverTime'] > 0 else 0, 1),
                'UserTime Reduction (%)': round(((vanilla_row['UserTime'] - evp_row['UserTime']) / 
                                                 vanilla_row['UserTime'] * 100) if vanilla_row['UserTime'] > 0 else 0, 1),
                'Coverage Delta': int(evp_row['FinalCoverage'] - vanilla_row['FinalCoverage']),
                'Memory Savings (MB)': round(vanilla_row['MemoryUsage'] - evp_row['MemoryUsage'], 1)
            }
            
            # Categorize program complexity based on characteristics
            if characteristics['Instructions'] < 25000:
                characteristics['Complexity'] = 'Low'
            elif characteristics['Instructions'] < 50000:
                characteristics['Complexity'] = 'Medium'
            else:
                characteristics['Complexity'] = 'High'
            
            rq3_results.append(characteristics)
    
    return pd.DataFrame(rq3_results)

def generate_latex_tables(rq1_df, rq2_df, rq3_df):
    """Generate LaTeX formatted tables for the paper"""
    
    latex_output = []
    
    # RQ1 Table
    latex_output.append("% ============ RQ1: Constraint Solving Time Comparison ============")
    latex_output.append("\\begin{table}[t]")
    latex_output.append("\\centering")
    latex_output.append("\\caption{Performance comparison between vanilla KLEE and EVP-enhanced KLEE}")
    latex_output.append("\\label{tab:rq1-performance}")
    latex_output.append("\\resizebox{\\columnwidth}{!}{%")
    latex_output.append("\\begin{tabular}{lrrrr}")
    latex_output.append("\\toprule")
    latex_output.append("\\textbf{Program} & \\textbf{Metric} & \\textbf{Vanilla} & \\textbf{EVP} & \\textbf{Improvement} \\\\")
    latex_output.append("\\midrule")
    
    for program in rq1_df['Program'].unique():
        program_data = rq1_df[rq1_df['Program'] == program]
        first_row = True
        for _, row in program_data.iterrows():
            if first_row:
                latex_output.append(f"\\multirow{{{len(program_data)}}}{{*}}{{\\texttt{{{program}}}}}")
                first_row = False
            else:
                latex_output.append("")
            
            # Format values based on metric type
            if row['Metric'] in ['Coverage (inst)', 'NumQueries']:
                vanilla_str = f"{int(row['Vanilla']):,}"
                evp_str = f"{int(row['EVP']):,}"
            else:
                vanilla_str = f"{row['Vanilla']:.2f}"
                evp_str = f"{row['EVP']:.2f}"
            
            improvement_str = f"\\textbf{{{row['Improvement (%)']:.1f}\\%}}" if row['Improvement (%)'] > 0 else f"{row['Improvement (%)']:.1f}\\%"
            
            latex_output.append(f" & {row['Metric']} & {vanilla_str} & {evp_str} & {improvement_str} \\\\")
        latex_output.append("\\midrule")
    
    latex_output.append("\\bottomrule")
    latex_output.append("\\end{tabular}%")
    latex_output.append("}")
    latex_output.append("\\end{table}")
    
    # RQ2 Table
    latex_output.append("\n% ============ RQ2: EVP Overhead Analysis ============")
    latex_output.append("\\begin{table}[t]")
    latex_output.append("\\centering")
    latex_output.append("\\caption{EVP overhead breakdown across profiling phases}")
    latex_output.append("\\label{tab:rq2-overhead}")
    latex_output.append("\\begin{tabular}{lrrrr}")
    latex_output.append("\\toprule")
    latex_output.append("\\textbf{Program} & \\textbf{Instrument} & \\textbf{Profile} & \\textbf{Analyze} & \\textbf{Total (\\%)} \\\\")
    latex_output.append("\\midrule")
    
    for _, row in rq2_df.iterrows():
        latex_output.append(f"\\texttt{{{row['Program']}}} & {row['Instrument (s)']:.1f}s & {row['Profile (s)']:.1f}s & "
                          f"{row['Analyze (s)']:.1f}s & {row['Total (s)']:.1f}s ({row['Overhead (%)']:.1f}\\%) \\\\")
    
    latex_output.append("\\bottomrule")
    latex_output.append("\\end{tabular}")
    latex_output.append("\\end{table}")
    
    # RQ3 Table
    latex_output.append("\n% ============ RQ3: Performance Variation Analysis ============")
    latex_output.append("\\begin{table}[t]")
    latex_output.append("\\centering")
    latex_output.append("\\caption{EVP performance variation across different program characteristics}")
    latex_output.append("\\label{tab:rq3-variation}")
    latex_output.append("\\resizebox{\\columnwidth}{!}{%")
    latex_output.append("\\begin{tabular}{lrrrrrrr}")
    latex_output.append("\\toprule")
    latex_output.append("\\textbf{Program} & \\textbf{Size} & \\textbf{Complexity} & \\textbf{NumQueries} & \\textbf{SolverTime} & \\textbf{UserTime} & \\textbf{Coverage} & \\textbf{Memory} \\\\")
    latex_output.append(" & \\textbf{(inst)} & & \\textbf{Red. (\\%)} & \\textbf{Red. (\\%)} & \\textbf{Red. (\\%)} & \\textbf{Delta} & \\textbf{Saved (MB)} \\\\")
    latex_output.append("\\midrule")
    
    for _, row in rq3_df.iterrows():
        latex_output.append(f"\\texttt{{{row['Program']}}} & {row['Instructions']:,} & {row['Complexity']} & "
                          f"{row['NumQueries Reduction (%)']:.1f} & {row['SolverTime Reduction (%)']:.1f} & "
                          f"{row['UserTime Reduction (%)']:.1f} & {row['Coverage Delta']:+d} & {row['Memory Savings (MB)']:.1f} \\\\")
    
    latex_output.append("\\bottomrule")
    latex_output.append("\\end{tabular}%")
    latex_output.append("}")
    latex_output.append("\\end{table}")
    
    return "\n".join(latex_output)

def main():
    """Main function to orchestrate all data processing"""
    
    print("=" * 60)
    print("EVP Performance Analysis Tool")
    print("=" * 60)
    
    # Load and process all data
    print("\n[*] Loading and processing CSV files...")
    df = load_and_process_data()
    
    if df.empty:
        print("[!] No data files found. Please check that CSV files are in:")
        print(f"    - results/temp_results/coreutils-tmp/{{program}}/{{program}}-stats-{{variant}}.csv")
        print(f"    - results/temp_results/libXML2-tmp/libXML2/libxml2-stats-{{variant}}.csv")
        return
    
    print(f"[+] Loaded {len(df)} data points from {df['Program'].nunique()} programs")
    
    # Prepare analysis for each RQ
    print("\n[*] Preparing RQ1 analysis (Constraint solving effectiveness)...")
    rq1_df = prepare_rq1_analysis(df)
    
    print("[*] Preparing RQ2 analysis (Overhead analysis)...")
    rq2_df = prepare_rq2_analysis(df)
    
    print("[*] Preparing RQ3 analysis (Performance variation)...")
    rq3_df = prepare_rq3_analysis(df)
    
    # Save to Excel
    output_file = 'evp_analysis_results.xlsx'
    print(f"\n[*] Saving results to {output_file}...")
    
    with pd.ExcelWriter(output_file, engine='openpyxl') as writer:
        rq1_df.to_excel(writer, sheet_name='RQ1_Performance', index=False)
        rq2_df.to_excel(writer, sheet_name='RQ2_Overhead', index=False)
        rq3_df.to_excel(writer, sheet_name='RQ3_Variation', index=False)
        df.to_excel(writer, sheet_name='Raw_Data', index=False)
    
    print(f"[+] Excel file saved successfully!")
    
    # Generate LaTeX tables
    latex_tables = generate_latex_tables(rq1_df, rq2_df, rq3_df)
    
    # Save LaTeX to file
    with open('latex_tables.tex', 'w') as f:
        f.write(latex_tables)
    print("[+] LaTeX tables saved to latex_tables.tex")
    
    # Print summary statistics
    print("\n" + "=" * 60)
    print("SUMMARY STATISTICS")
    print("=" * 60)
    
    print("\n[RQ1] Constraint Solving Performance:")
    print("-" * 40)
    avg_improvements = rq1_df[rq1_df['Metric'].str.contains('Time')].groupby('Metric')['Improvement (%)'].mean()
    for metric, improvement in avg_improvements.items():
        print(f"  Average {metric} improvement: {improvement:.1f}%")
    
    print("\n[RQ2] Overhead Analysis:")
    print("-" * 40)
    print(rq2_df[['Program', 'Total (s)', 'Overhead (%)']].to_string(index=False))
    print(f"  Average overhead: {rq2_df['Overhead (%)'].mean():.1f}%")
    
    print("\n[RQ3] Performance Variation:")
    print("-" * 40)
    for _, row in rq3_df.iterrows():
        print(f"  {row['Program']}: {row['Complexity']} complexity, "
              f"NumQueries reduction {row['NumQueries Reduction (%)']:.1f}%, "
              f"Coverage Delta {row['Coverage Delta']:+d}")
    
    print("\n" + "=" * 60)
    print("[+] Analysis complete! Check the following files:")
    print(f"  - {output_file}: Excel file with all analysis tables")
    print("  - latex_tables.tex: LaTeX formatted tables for paper")
    print("=" * 60)

if __name__ == "__main__":
    main()