#!/usr/bin/env python3

"""
Assembly Statistics and Visualization Script
Author: Brig-Bayo
License: MIT

This script provides comprehensive statistics and visualizations for genome assemblies.
"""

import argparse
import sys
import os
from pathlib import Path
from collections import defaultdict
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from Bio import SeqIO
import json


class AssemblyAnalyzer:
    """Class for analyzing genome assembly statistics."""
    
    def __init__(self, assembly_file):
        """Initialize with assembly file path."""
        self.assembly_file = Path(assembly_file)
        self.sequences = []
        self.stats = {}
        
        if not self.assembly_file.exists():
            raise FileNotFoundError(f"Assembly file not found: {assembly_file}")
            
        self._load_sequences()
        self._calculate_stats()
    
    def _load_sequences(self):
        """Load sequences from FASTA file."""
        try:
            self.sequences = list(SeqIO.parse(self.assembly_file, "fasta"))
            if not self.sequences:
                raise ValueError("No sequences found in the assembly file")
        except Exception as e:
            raise ValueError(f"Error reading assembly file: {e}")
    
    def _calculate_stats(self):
        """Calculate comprehensive assembly statistics."""
        lengths = [len(seq) for seq in self.sequences]
        lengths.sort(reverse=True)
        
        total_length = sum(lengths)
        num_contigs = len(lengths)
        
        # Calculate Nx statistics
        def calculate_nx(lengths, x):
            target = total_length * (x / 100)
            cumulative = 0
            for length in lengths:
                cumulative += length
                if cumulative >= target:
                    return length
            return 0
        
        # GC content
        total_gc = sum(seq.seq.count('G') + seq.seq.count('C') + 
                      seq.seq.count('g') + seq.seq.count('c') 
                      for seq in self.sequences)
        gc_content = (total_gc / total_length) * 100 if total_length > 0 else 0
        
        # N content
        total_n = sum(seq.seq.count('N') + seq.seq.count('n') 
                     for seq in self.sequences)
        n_content = (total_n / total_length) * 100 if total_length > 0 else 0
        
        self.stats = {
            'file': str(self.assembly_file),
            'num_contigs': num_contigs,
            'total_length': total_length,
            'longest_contig': max(lengths) if lengths else 0,
            'shortest_contig': min(lengths) if lengths else 0,
            'mean_length': total_length / num_contigs if num_contigs > 0 else 0,
            'median_length': np.median(lengths) if lengths else 0,
            'n50': calculate_nx(lengths, 50),
            'n90': calculate_nx(lengths, 90),
            'l50': self._calculate_lx(lengths, 50),
            'l90': self._calculate_lx(lengths, 90),
            'gc_content': gc_content,
            'n_content': n_content,
            'lengths': lengths
        }
    
    def _calculate_lx(self, lengths, x):
        """Calculate Lx (number of contigs needed to reach x% of total length)."""
        target = sum(lengths) * (x / 100)
        cumulative = 0
        for i, length in enumerate(lengths, 1):
            cumulative += length
            if cumulative >= target:
                return i
        return len(lengths)
    
    def get_basic_stats(self):
        """Return basic statistics dictionary."""
        return {k: v for k, v in self.stats.items() if k != 'lengths'}
    
    def print_stats(self):
        """Print formatted statistics."""
        print(f"\n{'='*50}")
        print(f"Assembly Statistics: {self.assembly_file.name}")
        print(f"{'='*50}")
        print(f"Number of contigs:     {self.stats['num_contigs']:,}")
        print(f"Total length:          {self.stats['total_length']:,} bp")
        print(f"Longest contig:        {self.stats['longest_contig']:,} bp")
        print(f"Shortest contig:       {self.stats['shortest_contig']:,} bp")
        print(f"Mean contig length:    {self.stats['mean_length']:,.0f} bp")
        print(f"Median contig length:  {self.stats['median_length']:,.0f} bp")
        print(f"N50:                   {self.stats['n50']:,} bp")
        print(f"N90:                   {self.stats['n90']:,} bp")
        print(f"L50:                   {self.stats['l50']:,} contigs")
        print(f"L90:                   {self.stats['l90']:,} contigs")
        print(f"GC content:            {self.stats['gc_content']:.2f}%")
        print(f"N content:             {self.stats['n_content']:.2f}%")
        print(f"{'='*50}\n")
    
    def save_stats_json(self, output_file):
        """Save statistics to JSON file."""
        stats_to_save = self.get_basic_stats()
        with open(output_file, 'w') as f:
            json.dump(stats_to_save, f, indent=2)
        print(f"Statistics saved to: {output_file}")
    
    def save_stats_tsv(self, output_file):
        """Save statistics to TSV file."""
        stats_to_save = self.get_basic_stats()
        df = pd.DataFrame([stats_to_save])
        df.to_csv(output_file, sep='\t', index=False)
        print(f"Statistics saved to: {output_file}")
    
    def plot_length_distribution(self, output_file=None, bins=50):
        """Create length distribution histogram."""
        plt.figure(figsize=(12, 8))
        
        # Main histogram
        plt.subplot(2, 2, 1)
        plt.hist(self.stats['lengths'], bins=bins, alpha=0.7, color='skyblue', edgecolor='black')
        plt.xlabel('Contig Length (bp)')
        plt.ylabel('Frequency')
        plt.title('Contig Length Distribution')
        plt.yscale('log')
        
        # Log-scale histogram
        plt.subplot(2, 2, 2)
        plt.hist(np.log10(self.stats['lengths']), bins=bins, alpha=0.7, color='lightcoral', edgecolor='black')
        plt.xlabel('Log10(Contig Length)')
        plt.ylabel('Frequency')
        plt.title('Log-scale Length Distribution')
        
        # Cumulative plot
        plt.subplot(2, 2, 3)
        cumulative_lengths = np.cumsum(sorted(self.stats['lengths'], reverse=True))
        plt.plot(range(1, len(cumulative_lengths) + 1), cumulative_lengths, 'b-', linewidth=2)
        plt.xlabel('Contig Rank')
        plt.ylabel('Cumulative Length (bp)')
        plt.title('Cumulative Length Plot')
        plt.grid(True, alpha=0.3)
        
        # Box plot
        plt.subplot(2, 2, 4)
        plt.boxplot(self.stats['lengths'], vert=True)
        plt.ylabel('Contig Length (bp)')
        plt.title('Length Distribution Box Plot')
        plt.yscale('log')
        
        plt.tight_layout()
        
        if output_file:
            plt.savefig(output_file, dpi=300, bbox_inches='tight')
            print(f"Length distribution plot saved to: {output_file}")
        else:
            plt.show()
    
    def plot_nx_curve(self, output_file=None):
        """Create Nx curve plot."""
        plt.figure(figsize=(10, 6))
        
        lengths = sorted(self.stats['lengths'], reverse=True)
        total_length = sum(lengths)
        
        # Calculate Nx values
        nx_values = []
        x_values = range(1, 100)
        
        for x in x_values:
            target = total_length * (x / 100)
            cumulative = 0
            for length in lengths:
                cumulative += length
                if cumulative >= target:
                    nx_values.append(length)
                    break
        
        plt.plot(x_values, nx_values, 'b-', linewidth=2, marker='o', markersize=3)
        plt.axhline(y=self.stats['n50'], color='red', linestyle='--', 
                   label=f"N50 = {self.stats['n50']:,} bp")
        plt.axvline(x=50, color='red', linestyle='--', alpha=0.5)
        
        plt.xlabel('X (%)')
        plt.ylabel('Nx (bp)')
        plt.title('Nx Curve')
        plt.grid(True, alpha=0.3)
        plt.legend()
        plt.yscale('log')
        
        if output_file:
            plt.savefig(output_file, dpi=300, bbox_inches='tight')
            print(f"Nx curve plot saved to: {output_file}")
        else:
            plt.show()


def compare_assemblies(assembly_files, output_dir=None):
    """Compare multiple assemblies and create comparison plots."""
    analyzers = []
    names = []
    
    for file in assembly_files:
        try:
            analyzer = AssemblyAnalyzer(file)
            analyzers.append(analyzer)
            names.append(Path(file).stem)
        except Exception as e:
            print(f"Error processing {file}: {e}")
            continue
    
    if len(analyzers) < 2:
        print("Need at least 2 valid assemblies for comparison")
        return
    
    # Create comparison DataFrame
    comparison_data = []
    for i, analyzer in enumerate(analyzers):
        stats = analyzer.get_basic_stats()
        stats['assembly'] = names[i]
        comparison_data.append(stats)
    
    df = pd.DataFrame(comparison_data)
    
    # Print comparison table
    print("\nAssembly Comparison:")
    print("=" * 80)
    comparison_cols = ['assembly', 'num_contigs', 'total_length', 'n50', 'gc_content']
    print(df[comparison_cols].to_string(index=False))
    print("=" * 80)
    
    # Create comparison plots
    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    
    # Number of contigs
    axes[0, 0].bar(names, [a.stats['num_contigs'] for a in analyzers])
    axes[0, 0].set_ylabel('Number of Contigs')
    axes[0, 0].set_title('Number of Contigs Comparison')
    axes[0, 0].tick_params(axis='x', rotation=45)
    
    # Total length
    axes[0, 1].bar(names, [a.stats['total_length'] for a in analyzers])
    axes[0, 1].set_ylabel('Total Length (bp)')
    axes[0, 1].set_title('Total Length Comparison')
    axes[0, 1].tick_params(axis='x', rotation=45)
    
    # N50
    axes[1, 0].bar(names, [a.stats['n50'] for a in analyzers])
    axes[1, 0].set_ylabel('N50 (bp)')
    axes[1, 0].set_title('N50 Comparison')
    axes[1, 0].tick_params(axis='x', rotation=45)
    
    # GC content
    axes[1, 1].bar(names, [a.stats['gc_content'] for a in analyzers])
    axes[1, 1].set_ylabel('GC Content (%)')
    axes[1, 1].set_title('GC Content Comparison')
    axes[1, 1].tick_params(axis='x', rotation=45)
    
    plt.tight_layout()
    
    if output_dir:
        output_file = Path(output_dir) / "assembly_comparison.png"
        plt.savefig(output_file, dpi=300, bbox_inches='tight')
        print(f"Comparison plot saved to: {output_file}")
        
        # Save comparison table
        table_file = Path(output_dir) / "assembly_comparison.tsv"
        df.to_csv(table_file, sep='\t', index=False)
        print(f"Comparison table saved to: {table_file}")
    else:
        plt.show()


def main():
    """Main function."""
    parser = argparse.ArgumentParser(
        description="Analyze genome assembly statistics and create visualizations",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Analyze single assembly
  python assembly_stats.py -i assembly.fasta

  # Analyze with plots
  python assembly_stats.py -i assembly.fasta -o output_dir --plot

  # Compare multiple assemblies
  python assembly_stats.py -i assembly1.fasta assembly2.fasta -o output_dir --compare

  # Save statistics in different formats
  python assembly_stats.py -i assembly.fasta --json stats.json --tsv stats.tsv
        """
    )
    
    parser.add_argument('-i', '--input', nargs='+', required=True,
                       help='Input assembly file(s) in FASTA format')
    parser.add_argument('-o', '--output', 
                       help='Output directory for plots and reports')
    parser.add_argument('--json', 
                       help='Save statistics to JSON file')
    parser.add_argument('--tsv', 
                       help='Save statistics to TSV file')
    parser.add_argument('--plot', action='store_true',
                       help='Generate distribution plots')
    parser.add_argument('--compare', action='store_true',
                       help='Compare multiple assemblies')
    parser.add_argument('--bins', type=int, default=50,
                       help='Number of bins for histograms (default: 50)')
    
    args = parser.parse_args()
    
    # Create output directory if specified
    if args.output:
        Path(args.output).mkdir(parents=True, exist_ok=True)
    
    if len(args.input) == 1 and not args.compare:
        # Single assembly analysis
        try:
            analyzer = AssemblyAnalyzer(args.input[0])
            analyzer.print_stats()
            
            # Save statistics
            if args.json:
                analyzer.save_stats_json(args.json)
            if args.tsv:
                analyzer.save_stats_tsv(args.tsv)
            
            # Generate plots
            if args.plot and args.output:
                length_plot = Path(args.output) / "length_distribution.png"
                nx_plot = Path(args.output) / "nx_curve.png"
                analyzer.plot_length_distribution(length_plot, bins=args.bins)
                analyzer.plot_nx_curve(nx_plot)
            elif args.plot:
                analyzer.plot_length_distribution(bins=args.bins)
                analyzer.plot_nx_curve()
                
        except Exception as e:
            print(f"Error analyzing assembly: {e}")
            sys.exit(1)
    
    elif len(args.input) > 1 or args.compare:
        # Multiple assembly comparison
        compare_assemblies(args.input, args.output)
    
    else:
        print("Error: Please provide at least one input file")
        sys.exit(1)


if __name__ == "__main__":
    main()
