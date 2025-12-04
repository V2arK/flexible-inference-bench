#!/usr/bin/env python3
"""
Performance Comparison Plotter
Reads metrics JSON from analyze-results.sh and creates comparison plots with claim/reference data.

Usage:
    python plot-comparison.py <metrics_json_file> <claims_json_file> [output_dir]
    python plot-comparison.py <metrics_json_file> --inline-claims '<json_data>' [output_dir]

Examples:
    python plot-comparison.py results/metrics-data.json claims.json
    python plot-comparison.py results/metrics-data.json --inline-claims '{"mean_ttft": [[1, 195], [2, 183]]}'
"""

import json
import sys
import os
import argparse
import matplotlib.pyplot as plt
import matplotlib.style as style
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import numpy as np

# Set a clean style for plots
plt.style.use('default')
plt.rcParams['figure.figsize'] = (12, 8)
plt.rcParams['font.size'] = 12
plt.rcParams['axes.grid'] = True
plt.rcParams['grid.alpha'] = 0.3

class PerformanceComparisonPlotter:
    def __init__(self):
        self.colors = {
            'actual': '#2E86AB',      # Blue
            'claimed': '#A23B72',     # Purple/Pink
            'difference': '#F18F01',  # Orange
        }
        
        self.metric_info = {
            'mean_ttft': {
                'title': 'Mean Time to First Token (TTFT)',
                'ylabel': 'Time (ms)',
                'description': 'Lower is better'
            },
            'p99_ttft': {
                'title': 'P99 Time to First Token (TTFT)', 
                'ylabel': 'Time (ms)',
                'description': 'Lower is better'
            },
            'input_token_throughput': {
                'title': 'Input Token Throughput',
                'ylabel': 'Tokens per second',
                'description': 'Higher is better'
            },
            'output_token_throughput': {
                'title': 'Output Token Throughput',
                'ylabel': 'Tokens per second',
                'description': 'Higher is better'
            },
            'throughput': {
                'title': 'Request Throughput (Legacy)',
                'ylabel': 'Requests per second',
                'description': 'Higher is better'
            },
            'output_tp': {
                'title': 'Output Token Throughput (Claims)',
                'ylabel': 'Tokens per second',
                'description': 'Higher is better'
            },
            'mean_tpot': {
                'title': 'Mean Time per Output Token (TPOT)',
                'ylabel': 'Time (ms)',
                'description': 'Lower is better'
            },
            'p99_tpot': {
                'title': 'P99 Time per Output Token (TPOT)',
                'ylabel': 'Time (ms)',
                'description': 'Lower is better'
            },
            'mean_itl': {
                'title': 'Mean Inter-token Latency (ITL)',
                'ylabel': 'Time (ms)',
                'description': 'Lower is better'
            },
            'p99_itl': {
                'title': 'P99 Inter-token Latency (ITL)',
                'ylabel': 'Time (ms)',
                'description': 'Lower is better'
            },
            'successful_requests': {
                'title': 'Successful Requests',
                'ylabel': 'Number of requests',
                'description': 'Higher is better'
            },
            'duration': {
                'title': 'Test Duration',
                'ylabel': 'Time (seconds)',
                'description': 'Context dependent'
            }
        }
    
    def load_json_file(self, file_path: str) -> Dict:
        """Load JSON data from file."""
        try:
            with open(file_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"Error: File '{file_path}' not found.")
            sys.exit(1)
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON in '{file_path}': {e}")
            sys.exit(1)
    
    def parse_inline_claims(self, claims_str: str) -> Dict:
        """Parse inline JSON claims data."""
        try:
            return json.loads(claims_str)
        except json.JSONDecodeError as e:
            print(f"Error: Invalid inline JSON: {e}")
            sys.exit(1)
    
    def format_coordinate_label(self, x: float, y: float) -> str:
        """Format coordinate label for display."""
        return f'({int(x)}, {y:.1f})'
    
    def calculate_smart_label_positions(self, data_points, ax, is_actual=True):
        """Calculate smart label positions to avoid overlaps."""
        positions = []
        
        print(f"  📍 {'Actual' if is_actual else 'Claims'} data points: {data_points}")
        
        if not data_points:
            return positions
        
        # Calculate relative spacing between all points
        x_values = [x for x, y in data_points]
        if len(x_values) > 1:
            x_range = max(x_values) - min(x_values)
            avg_spacing = x_range / (len(x_values) - 1)
        else:
            avg_spacing = 100  # Default for single point
            
        print(f"    X-range: {x_range if len(x_values) > 1 else 'N/A'}, Avg spacing: {avg_spacing:.1f}")
        
        for i, (x, y) in enumerate(data_points):
            # Calculate local density around this point
            nearby_points = 0
            for j, (other_x, other_y) in enumerate(data_points):
                if i != j and abs(x - other_x) < avg_spacing * 0.5:
                    nearby_points += 1
            
            # Base positioning strategy
            base_distance = 8
            
            # More sophisticated positioning based on position in sequence and local density
            if nearby_points > 2:  # Very crowded area
                # Use more extreme offsets and more positions
                position_pattern = i % 8
                offsets = [
                    (5, 20), (-30, 15), (25, -8), (-20, -20),
                    (35, 5), (-35, 25), (15, -25), (-15, 30)
                ]
                offset_x, offset_y = offsets[position_pattern]
                if not is_actual:
                    offset_y = -offset_y  # Flip for claims data
                    
            elif nearby_points > 1:  # Moderately crowded
                # Use 6 different positions
                position_pattern = i % 6
                offsets = [
                    (5, 15), (-25, 12), (20, -5), (-15, -15), (30, 8), (-20, 20)
                ]
                offset_x, offset_y = offsets[position_pattern]
                if not is_actual:
                    offset_y = -offset_y
                    
            elif nearby_points > 0:  # Some nearby points
                # Simple alternating with slight variations
                if i % 3 == 0:
                    offset_x, offset_y = 5, base_distance
                elif i % 3 == 1:
                    offset_x, offset_y = -20, base_distance + 5
                else:
                    offset_x, offset_y = 15, -base_distance + 3
                if not is_actual:
                    offset_y = -offset_y
                    
            else:  # Isolated points
                offset_x, offset_y = 5, base_distance if is_actual else -base_distance
            
            # Additional adjustments based on y-value clustering
            if i > 0:
                prev_y = data_points[i-1][1]
                if abs(y - prev_y) < (max([pt[1] for pt in data_points]) - min([pt[1] for pt in data_points])) * 0.1:
                    # Y-values are close, need more separation
                    offset_y += 10 if offset_y > 0 else -10
                    offset_x += 10 if i % 2 == 0 else -15
            
            # Determine text alignment based on offset
            ha = 'left' if offset_x >= 0 else 'right'
            va = 'bottom' if offset_y >= 0 else 'top'
            
            positions.append({
                'x': x, 'y': y,
                'offset_x': offset_x, 'offset_y': offset_y,
                'ha': ha, 'va': va,
                'nearby_points': nearby_points
            })
            
            print(f"    Point {i}: ({x}, {y:.1f}) -> offset({offset_x}, {offset_y}), nearby: {nearby_points}")
        
        return positions
    
    def create_comparison_plot(self, metric_name: str, actual_data: List[Tuple[float, float]], 
                             claims_data: List[Tuple[float, float]], output_dir: str):
        """Create a comparison plot for a specific metric."""
        
        # Create side-by-side plots: linear and log scale
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(20, 10))
        
        # Extract data for plotting
        actual_x = [point[0] for point in actual_data]
        actual_y = [point[1] for point in actual_data]
        
        # Use claims data as-is (no interpolation)
        claims_x = [point[0] for point in claims_data] if claims_data else []
        claims_y = [point[1] for point in claims_data] if claims_data else []
        
        # Get metric info
        metric_info = self.metric_info.get(metric_name, {
            'title': metric_name.replace('_', ' ').title(),
            'ylabel': 'Value',
            'description': ''
        })
        
        # Helper function to plot on an axis
        def plot_on_axis(ax, title_suffix, use_log_scale=False):
            # Plot actual performance with enhanced styling
            ax.plot(actual_x, actual_y, 'o-', color=self.colors['actual'], 
                    linewidth=3, markersize=10, label='Actual Performance', 
                    alpha=0.9, markeredgewidth=2, markeredgecolor='white')
            
            # Calculate smart positions for actual data labels
            actual_data_tuples = list(zip(actual_x, actual_y))
            actual_positions = self.calculate_smart_label_positions(actual_data_tuples, ax, is_actual=True)
            
            # Add coordinate labels for actual data points (using smart positioning)
            for i, pos in enumerate(actual_positions):
                if i % 2 == 0:  # Show every second data point
                    ax.annotate(self.format_coordinate_label(pos['x'], pos['y']), 
                               (pos['x'], pos['y']), 
                               xytext=(pos['offset_x'], pos['offset_y']), 
                               textcoords='offset points',
                               fontsize=7,
                               ha=pos['ha'],
                               va=pos['va'],
                               bbox=dict(boxstyle='round,pad=0.2', facecolor='lightblue', alpha=0.7, edgecolor='none'),
                               color='darkblue',
                               weight='bold')
            
            # Plot claims data if available (as-is, no interpolation)
            if claims_data:
                ax.plot(claims_x, claims_y, 's--', color=self.colors['claimed'],
                        linewidth=3, markersize=10, label='Claimed/Reference Performance', 
                        alpha=0.9, markeredgewidth=2, markeredgecolor='white')
                
                # Calculate smart positions for claims data labels
                claims_data_tuples = list(zip(claims_x, claims_y))
                claims_positions = self.calculate_smart_label_positions(claims_data_tuples, ax, is_actual=False)
                
                # Add coordinate labels for claims data points (using smart positioning, offset from actual)
                for i, pos in enumerate(claims_positions):
                    if i % 2 == 1:  # Show every second data point, offset from actual data labels
                        ax.annotate(self.format_coordinate_label(pos['x'], pos['y']), 
                                   (pos['x'], pos['y']), 
                                   xytext=(pos['offset_x'], pos['offset_y']), 
                                   textcoords='offset points',
                                   fontsize=7,
                                   ha=pos['ha'],
                                   va=pos['va'],
                                   bbox=dict(boxstyle='round,pad=0.2', facecolor='lightcoral', alpha=0.7, edgecolor='none'),
                                   color='darkred',
                                   weight='bold')
            
            # Set log scale if requested
            if use_log_scale:
                ax.set_xscale('log')
            
            # Enhanced styling with smaller fonts
            ax.set_xlabel('Concurrency Level' + (' (Log Scale)' if use_log_scale else ''), 
                         fontsize=10, fontweight='bold')
            ax.set_ylabel(metric_info['ylabel'], fontsize=10, fontweight='bold')
            ax.set_title(f'{title_suffix}', 
                        fontsize=11, fontweight='bold', pad=10)
            
            # Elegant legend with smaller font
            legend = ax.legend(fontsize=8, frameon=True, fancybox=True, shadow=True, loc='best')
            legend.get_frame().set_facecolor('white')
            legend.get_frame().set_alpha(0.95)
            
            # Enhanced grid
            ax.grid(True, alpha=0.3, linestyle='-', linewidth=0.5)
            ax.set_axisbelow(True)
            
            # Set spine colors and thickness for elegance
            for spine in ax.spines.values():
                spine.set_color('#CCCCCC')
                spine.set_linewidth(1.5)
        
        # Plot 1: Linear scale
        plot_on_axis(ax1, "Linear Scale", use_log_scale=False)
        
        # Plot 2: Log scale
        plot_on_axis(ax2, "Log Scale", use_log_scale=True)
        
        # Add overall title with smaller font and better positioning
        fig.suptitle(f'{metric_info["title"]} - Performance Comparison', 
                    fontsize=13, fontweight='bold', y=0.96)
        
        # Add description with elegant styling (only on first plot)
        if metric_info['description']:
            ax1.text(0.02, 0.95, metric_info['description'], transform=ax1.transAxes,
                    verticalalignment='top', fontsize=8,
                    bbox=dict(boxstyle='round,pad=0.3', facecolor='lightyellow', alpha=0.8, edgecolor='orange', linewidth=1))
        
        plt.tight_layout()
        
        # Save plot with high quality
        output_file = os.path.join(output_dir, f'{metric_name}_comparison.png')
        plt.savefig(output_file, dpi=300, bbox_inches='tight', facecolor='white', edgecolor='none')
        plt.close()
        
        print(f"  📊 Generated: {output_file}")
        
        return output_file
    
    def create_summary_plot(self, metrics_data: Dict, claims_data: Dict, output_dir: str):
        """Create a summary plot showing multiple metrics."""
        # Select key metrics for summary
        key_metrics = ['mean_ttft', 'input_token_throughput', 'output_token_throughput', 'mean_tpot']
        available_metrics = [m for m in key_metrics if m in metrics_data]
        
        if not available_metrics:
            print("  ⚠️  No key metrics available for summary plot")
            return None
        
        fig, axes = plt.subplots(len(available_metrics), 1, figsize=(14, 5*len(available_metrics)))
        if len(available_metrics) == 1:
            axes = [axes]
        
        for i, metric in enumerate(available_metrics):
            actual_data = metrics_data[metric]
            claims_metric_data = claims_data.get(metric, [])
            
            actual_x = [point[0] for point in actual_data]
            actual_y = [point[1] for point in actual_data]
            
            # Plot actual data with enhanced styling
            axes[i].plot(actual_x, actual_y, 'o-', color=self.colors['actual'],
                         linewidth=2.5, markersize=7, label='Actual', alpha=0.9,
                         markeredgewidth=1, markeredgecolor='white')
            
            # Plot claims data as-is (no interpolation)
            if claims_metric_data:
                claims_x = [point[0] for point in claims_metric_data]
                claims_y = [point[1] for point in claims_metric_data]
                
                axes[i].plot(claims_x, claims_y, 's--', color=self.colors['claimed'],
                             linewidth=2.5, markersize=7, label='Claimed', alpha=0.9,
                             markeredgewidth=1, markeredgecolor='white')
            
            # Enhanced styling for each subplot with smaller fonts
            metric_info = self.metric_info.get(metric, {'title': metric, 'ylabel': 'Value'})
            axes[i].set_xlabel('Concurrency Level', fontsize=10, fontweight='bold')
            axes[i].set_ylabel(metric_info['ylabel'], fontsize=10, fontweight='bold')
            axes[i].set_title(metric_info['title'], fontsize=11, fontweight='bold', pad=10)
            
            # Elegant legend with smaller font
            legend = axes[i].legend(fontsize=9, frameon=True, fancybox=True, shadow=True, loc='best')
            legend.get_frame().set_facecolor('white')
            legend.get_frame().set_alpha(0.95)
            
            # Enhanced grid
            axes[i].grid(True, alpha=0.3, linestyle='-', linewidth=0.5)
            axes[i].set_axisbelow(True)
            
            # Set spine colors
            for spine in axes[i].spines.values():
                spine.set_color('#CCCCCC')
                spine.set_linewidth(1.5)
        
        plt.suptitle('Performance Comparison Summary', fontsize=14, fontweight='bold', y=0.97)
        plt.tight_layout()
        
        output_file = os.path.join(output_dir, 'summary_comparison.png')
        plt.savefig(output_file, dpi=300, bbox_inches='tight', facecolor='white', edgecolor='none')
        plt.close()
        
        print(f"  📊 Generated: {output_file}")
        return output_file
    
    def generate_report(self, metrics_data: Dict, claims_data: Dict, 
                       metrics_file: str, output_dir: str):
        """Generate a markdown report with performance analysis."""
        
        report_file = os.path.join(output_dir, 'comparison_report.md')
        
        with open(report_file, 'w') as f:
            f.write("# Performance Comparison Report\n\n")
            f.write(f"Generated: {os.popen('date').read().strip()}\n\n")
            f.write(f"**Metrics Source**: {metrics_file}\n")
            f.write(f"**Output Directory**: {output_dir}\n\n")
            
            # Metadata from metrics file
            metadata = metrics_data.get('metadata', {})
            if metadata:
                f.write("## Test Configuration\n\n")
                for key, value in metadata.items():
                    f.write(f"- **{key.replace('_', ' ').title()}**: {value}\n")
                f.write("\n")
            
            # Metrics analysis
            metrics = metrics_data.get('metrics', {})
            f.write("## Metrics Analysis\n\n")
            
            for metric_name in metrics.keys():
                metric_info = self.metric_info.get(metric_name, {})
                f.write(f"### {metric_info.get('title', metric_name.title())}\n\n")
                
                actual_data = metrics[metric_name]
                claims_metric_data = claims_data.get(metric_name, [])
                
                if actual_data:
                    min_val = min(point[1] for point in actual_data)
                    max_val = max(point[1] for point in actual_data)
                    f.write(f"- **Range**: {min_val:.2f} - {max_val:.2f} {metric_info.get('ylabel', '')}\n")
                
                if claims_metric_data:
                    f.write(f"- **Claims Data Points**: {len(claims_metric_data)}\n")
                    f.write(f"- **Comparison**: Available\n")
                else:
                    f.write(f"- **Comparison**: No claims data available\n")
                
                f.write(f"- **Plot**: {metric_name}_comparison.png\n\n")
            
            f.write("## Generated Files\n\n")
            f.write("### Individual Metric Plots\n")
            for metric_name in metrics.keys():
                f.write(f"- `{metric_name}_comparison.png`\n")
            
            f.write("\n### Summary Files\n")
            f.write("- `summary_comparison.png` - Key metrics overview\n")
            f.write("- `comparison_report.md` - This report\n\n")
            
            f.write("## Usage Notes\n\n")
            f.write("- **Blue labels** show actual performance coordinates\n")
            f.write("- **Red labels** show claimed/reference performance coordinates\n") 
            f.write("- Missing claims data results in actual-only plots\n")
            f.write("- Claims data is plotted as-is without interpolation\n")
        
        print(f"  📄 Generated: {report_file}")
        return report_file
    
    def plot_comparisons(self, metrics_file: str, claims_file: Optional[str] = None, 
                        inline_claims: Optional[str] = None, output_dir: Optional[str] = None):
        """Main method to generate all comparison plots."""
        
        print(f"🚀 Performance Comparison Plotter")
        print(f"📊 Metrics file: {metrics_file}")
        
        # Default output directory is inside the results folder
        if output_dir is None:
            metrics_dir = os.path.dirname(metrics_file)
            if metrics_dir:
                output_dir = os.path.join(metrics_dir, "comparison_plots")
            else:
                output_dir = "comparison_plots"
        
        # Load metrics data
        metrics_data = self.load_json_file(metrics_file)
        
        # Load claims data
        claims_data = {}
        if claims_file:
            print(f"📊 Claims file: {claims_file}")
            claims_data = self.load_json_file(claims_file)
        elif inline_claims:
            print(f"📊 Using inline claims data")
            claims_data = self.parse_inline_claims(inline_claims)
        else:
            print(f"⚠️  No claims data provided - generating actual-only plots")
        
        # Create output directory
        os.makedirs(output_dir, exist_ok=True)
        print(f"📁 Output directory: {output_dir}")
        
        # Extract metrics from the loaded data
        metrics = metrics_data.get('metrics', {})
        if not metrics:
            print("❌ No metrics found in the input file")
            return
        
        print(f"\n📈 Generating plots for {len(metrics)} metrics...")
        
        # Generate individual metric plots
        generated_plots = []
        for metric_name, metric_values in metrics.items():
            claims_metric_data = claims_data.get(metric_name, [])
            plot_file = self.create_comparison_plot(
                metric_name, metric_values, claims_metric_data, output_dir
            )
            generated_plots.append(plot_file)
        
        # Generate summary plot
        print(f"\n📈 Generating summary plot...")
        summary_plot = self.create_summary_plot(metrics_data.get('metrics', {}), claims_data, output_dir)
        
        # Generate report
        print(f"\n📄 Generating comparison report...")
        report_file = self.generate_report(metrics_data, claims_data, metrics_file, output_dir)
        
        print(f"\n✅ Comparison complete!")
        print(f"📁 All files saved to: {output_dir}/")
        print(f"📊 Generated {len(generated_plots)} individual metric plots")
        if summary_plot:
            print(f"📊 Generated summary plot")
        print(f"📄 Generated comparison report")


def main():
    parser = argparse.ArgumentParser(description='Generate performance comparison plots')
    parser.add_argument('metrics_file', help='Path to metrics JSON file from analyze-results.sh')
    parser.add_argument('claims_file', nargs='?', help='Path to claims/reference JSON file')
    parser.add_argument('--inline-claims', help='Inline JSON claims data')
    parser.add_argument('--output-dir', default=None, 
                       help='Output directory for plots (default: <metrics_dir>/comparison_plots)')
    
    args = parser.parse_args()
    
    # Validate arguments
    if not args.claims_file and not args.inline_claims:
        print("⚠️  No claims data provided. Will generate actual-only plots.")
    
    if args.claims_file and args.inline_claims:
        print("❌ Error: Provide either --claims-file OR --inline-claims, not both")
        sys.exit(1)
    
    # Create plotter and generate plots
    plotter = PerformanceComparisonPlotter()
    plotter.plot_comparisons(
        metrics_file=args.metrics_file,
        claims_file=args.claims_file,
        inline_claims=args.inline_claims,
        output_dir=args.output_dir
    )


if __name__ == "__main__":
    main()
