#!/bin/bash

# Concurrency Test Results Analyzer
# This script analyzes all JSON result files in a directory and exports analysis to text files
# Usage: ./analyze-results.sh <results_directory> [output_directory]

set -e

# Function to display usage
usage() {
    echo "Usage: $0 <results_directory> [output_directory]"
    echo ""
    echo "Parameters:"
    echo "  results_directory   Directory containing *-results.json files to analyze"
    echo "  output_directory    Optional custom output directory (default: analysis-exports)"
    echo ""
    echo "Examples:"
    echo "  $0 concurrency-test-results-4replica"
    echo "  $0 concurrency-test-results-Qwen_Qwen2.5-VL-7B-Instruct"
    echo "  $0 concurrency-test-results-4replica custom-analysis-output"
    echo ""
    echo "This script will:"
    echo "  - Find all *-results.json files in the specified directory"
    echo "  - Run 'fib analyse' on each file"
    echo "  - Save analysis output to [output_directory]/[test-name]-analysis.txt"
    exit 1
}

# Check if required parameters are provided
if [ $# -lt 1 ]; then
    echo "Error: Missing required parameters"
    echo ""
    usage
fi

# Parse command line arguments
RESULTS_DIR="$1"
OUTPUT_DIR="${2:-analysis-exports}"

# Check if results directory exists
if [ ! -d "$RESULTS_DIR" ]; then
    echo "Error: Results directory '$RESULTS_DIR' does not exist"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Concurrency Test Results Analyzer ==="
echo "Results directory: $RESULTS_DIR"
echo "Output directory: $RESULTS_DIR/$OUTPUT_DIR"
echo ""

# Create output directory inside the results directory
FULL_OUTPUT_DIR="$RESULTS_DIR/$OUTPUT_DIR"
mkdir -p "$FULL_OUTPUT_DIR"

# Find all result JSON files
JSON_FILES=$(find "$RESULTS_DIR" -maxdepth 1 -name "*-results.json" -type f | sort)

if [ -z "$JSON_FILES" ]; then
    echo -e "${YELLOW}⚠️  No *-results.json files found in $RESULTS_DIR${NC}"
    echo "Make sure you've run the concurrency tests first."
    exit 1
fi

# Count files
FILE_COUNT=$(echo "$JSON_FILES" | wc -l)
echo -e "${BLUE}📊 Found $FILE_COUNT result files to analyze${NC}"
echo ""

# Counter for progress
CURRENT=0

# Function to get concurrency level from test name
get_concurrency_level() {
    local test_name=$1
    case $test_name in
        "concurrency-low") echo "2" ;;
        "concurrency-medium") echo "10" ;;
        "concurrency-high") echo "25" ;;
        "concurrency-extreme") echo "50" ;;
        "concurrency-stress") echo "100" ;;
        "concurrency-ultra") echo "150" ;;
        "concurrency-massive") echo "300" ;;
        "concurrency-maximum") echo "500" ;;
        "concurrency-peak") echo "750" ;;
        "concurrency-burst") echo "1000" ;;
        *) echo "0" ;;
    esac
}

# Arrays to store metrics data for JSON output
declare -a CONCURRENCY_LEVELS=()
declare -a MEAN_TTFT=()
declare -a P99_TTFT=()
declare -a THROUGHPUT=()
declare -a MEAN_TPOT=()
declare -a P99_TPOT=()
declare -a MEAN_ITL=()
declare -a P99_ITL=()
declare -a SUCCESSFUL_REQUESTS=()
declare -a DURATION=()

# Function to analyze a single file
analyze_file() {
    local json_file=$1
    local filename=$(basename "$json_file")
    local test_name=$(echo "$filename" | sed 's/-results\.json$//')
    local output_file="$FULL_OUTPUT_DIR/${test_name}-analysis.txt"
    
    CURRENT=$((CURRENT + 1))
    
    echo -e "${BLUE}[$CURRENT/$FILE_COUNT] Analyzing: $filename${NC}"
    echo "  Output: $output_file"
    
    # Run fib analyse and capture output
    if fib analyse "$json_file" > "$output_file" 2>&1; then
        echo -e "${GREEN}  ✅ Analysis completed successfully${NC}"
        
        # Show a brief summary of the analysis and extract metrics for JSON
        if [ -f "$output_file" ]; then
            req_count=$(grep "Successful requests:" "$output_file" | awk '{print $3}' || echo "N/A")
            duration=$(grep "Benchmark duration" "$output_file" | awk '{print $4}' || echo "N/A")
            throughput=$(grep "Request throughput" "$output_file" | awk '{print $4}' || echo "N/A")
            mean_ttft=$(grep "Mean TTFT" "$output_file" | awk '{print $4}' || echo "N/A")
            
            echo "  📈 Quick Summary:"
            echo "     Requests: $req_count | Duration: ${duration}s | Throughput: ${throughput} req/s | TTFT: ${mean_ttft}ms"
            
            # Extract all metrics for JSON output
            local concurrency_level=$(get_concurrency_level "$test_name")
            local p99_ttft=$(grep "P99 TTFT" "$output_file" | awk '{print $4}' || echo "0")
            local mean_tpot=$(grep "Mean TPOT" "$output_file" | awk '{print $4}' || echo "0")
            local p99_tpot=$(grep "P99 TPOT" "$output_file" | awk '{print $4}' || echo "0")
            local mean_itl=$(grep "Mean ITL" "$output_file" | awk '{print $4}' || echo "0")
            local p99_itl=$(grep "P99 ITL" "$output_file" | awk '{print $4}' || echo "0")
            
            # Store metrics in arrays (only if we have valid numeric values)
            if [[ "$concurrency_level" != "0" ]] && [[ "$mean_ttft" != "N/A" ]]; then
                CONCURRENCY_LEVELS+=("$concurrency_level")
                MEAN_TTFT+=("$mean_ttft")
                P99_TTFT+=("$p99_ttft")
                THROUGHPUT+=("$throughput")
                MEAN_TPOT+=("$mean_tpot")
                P99_TPOT+=("$p99_tpot")
                MEAN_ITL+=("$mean_itl")
                P99_ITL+=("$p99_itl")
                SUCCESSFUL_REQUESTS+=("$req_count")
                DURATION+=("$duration")
            fi
        fi
    else
        echo -e "${RED}  ❌ Analysis failed - check $output_file for details${NC}"
    fi
    
    echo ""
}

# Analyze each file
echo -e "${GREEN}🚀 Starting analysis...${NC}"
echo ""

for json_file in $JSON_FILES; do
    analyze_file "$json_file"
done

echo -e "${BLUE}=== Analysis Complete ===${NC}"
echo ""

# Function to sort all metric arrays by concurrency level
sort_metrics_by_concurrency() {
    if [ ${#CONCURRENCY_LEVELS[@]} -eq 0 ]; then
        return
    fi
    
    # Create temporary arrays with indices for sorting
    local temp_data=()
    for i in "${!CONCURRENCY_LEVELS[@]}"; do
        temp_data+=("${CONCURRENCY_LEVELS[$i]}|$i")
    done
    
    # Sort by concurrency level (first part before |)
    IFS=$'\n' sorted_indices=($(printf '%s\n' "${temp_data[@]}" | sort -n | cut -d'|' -f2))
    unset IFS
    
    # Create new sorted arrays
    local new_concurrency=()
    local new_mean_ttft=()
    local new_p99_ttft=()
    local new_throughput=()
    local new_mean_tpot=()
    local new_p99_tpot=()
    local new_mean_itl=()
    local new_p99_itl=()
    local new_requests=()
    local new_duration=()
    
    for idx in "${sorted_indices[@]}"; do
        new_concurrency+=("${CONCURRENCY_LEVELS[$idx]}")
        new_mean_ttft+=("${MEAN_TTFT[$idx]}")
        new_p99_ttft+=("${P99_TTFT[$idx]}")
        new_throughput+=("${THROUGHPUT[$idx]}")
        new_mean_tpot+=("${MEAN_TPOT[$idx]}")
        new_p99_tpot+=("${P99_TPOT[$idx]}")
        new_mean_itl+=("${MEAN_ITL[$idx]}")
        new_p99_itl+=("${P99_ITL[$idx]}")
        new_requests+=("${SUCCESSFUL_REQUESTS[$idx]}")
        new_duration+=("${DURATION[$idx]}")
    done
    
    # Replace original arrays with sorted ones
    CONCURRENCY_LEVELS=("${new_concurrency[@]}")
    MEAN_TTFT=("${new_mean_ttft[@]}")
    P99_TTFT=("${new_p99_ttft[@]}")
    THROUGHPUT=("${new_throughput[@]}")
    MEAN_TPOT=("${new_mean_tpot[@]}")
    P99_TPOT=("${new_p99_tpot[@]}")
    MEAN_ITL=("${new_mean_itl[@]}")
    P99_ITL=("${new_p99_itl[@]}")
    SUCCESSFUL_REQUESTS=("${new_requests[@]}")
    DURATION=("${new_duration[@]}")
}

# Function to generate JSON metrics data
generate_metrics_json() {
    # Sort metrics by concurrency level first
    sort_metrics_by_concurrency
    
    local json_file="$FULL_OUTPUT_DIR/metrics-data.json"
    echo -e "${BLUE}📊 Generating metrics JSON: $json_file${NC}"
    
    # Create arrays of [concurrency, value] pairs for each metric
    cat > "$json_file" << EOF
{
    "metadata": {
        "generated": "$(date)",
        "results_directory": "$RESULTS_DIR",
        "total_tests": ${#CONCURRENCY_LEVELS[@]},
        "description": "Performance metrics vs concurrency levels extracted from analysis files"
    },
    "metrics": {
EOF

    # Helper function to generate metric array
    generate_metric_array() {
        local metric_name="$1"
        local array_name="$2"
        
        echo "        \"$metric_name\": [" >> "$json_file"
        
        # Use eval to access array by name
        for i in "${!CONCURRENCY_LEVELS[@]}"; do
            local concurrency="${CONCURRENCY_LEVELS[$i]}"
            eval "local value=\"\${${array_name}[$i]}\""
            
            # Add comma except for last element
            if [ $i -eq $((${#CONCURRENCY_LEVELS[@]} - 1)) ]; then
                echo "            [$concurrency, $value]" >> "$json_file"
            else
                echo "            [$concurrency, $value]," >> "$json_file"
            fi
        done
        
        echo "        ]" >> "$json_file"
    }
    
    # Generate arrays for each metric
    if [ ${#CONCURRENCY_LEVELS[@]} -gt 0 ]; then
        generate_metric_array "mean_ttft" "MEAN_TTFT"
        echo "," >> "$json_file"
        generate_metric_array "p99_ttft" "P99_TTFT"  
        echo "," >> "$json_file"
        generate_metric_array "throughput" "THROUGHPUT"
        echo "," >> "$json_file"
        generate_metric_array "mean_tpot" "MEAN_TPOT"
        echo "," >> "$json_file"
        generate_metric_array "p99_tpot" "P99_TPOT"
        echo "," >> "$json_file"
        generate_metric_array "mean_itl" "MEAN_ITL"
        echo "," >> "$json_file"
        generate_metric_array "p99_itl" "P99_ITL"
        echo "," >> "$json_file"
        generate_metric_array "successful_requests" "SUCCESSFUL_REQUESTS"
        echo "," >> "$json_file"
        generate_metric_array "duration" "DURATION"
    fi
    
    cat >> "$json_file" << EOF
    }
}
EOF

    echo -e "${GREEN}✅ Metrics JSON saved: $json_file${NC}"
    echo "   Contains ${#CONCURRENCY_LEVELS[@]} data points across 9 metrics"
}

# Generate summary report
SUMMARY_FILE="$FULL_OUTPUT_DIR/analysis-summary.md"
echo -e "${BLUE}📄 Generating summary report: $SUMMARY_FILE${NC}"

cat > "$SUMMARY_FILE" << EOF
# Concurrency Test Analysis Summary

Generated: $(date)
Results Directory: $RESULTS_DIR
Analysis Directory: $FULL_OUTPUT_DIR

## Analysis Files Generated

EOF

# List all analysis files with brief stats
for json_file in $JSON_FILES; do
    filename=$(basename "$json_file")
    test_name=$(echo "$filename" | sed 's/-results\.json$//')
    output_file="$FULL_OUTPUT_DIR/${test_name}-analysis.txt"
    
    if [ -f "$output_file" ]; then
        echo "### $test_name" >> "$SUMMARY_FILE"
        echo "- **File**: ${test_name}-analysis.txt" >> "$SUMMARY_FILE"
        echo "- **Source**: $filename" >> "$SUMMARY_FILE"
        
        # Extract key metrics
        req_count=$(grep "Successful requests:" "$output_file" | awk '{print $3}' 2>/dev/null || echo "N/A")
        duration=$(grep "Benchmark duration" "$output_file" | awk '{print $4}' 2>/dev/null || echo "N/A")
        throughput=$(grep "Request throughput" "$output_file" | awk '{print $4}' 2>/dev/null || echo "N/A")
        mean_ttft=$(grep "Mean TTFT" "$output_file" | awk '{print $4}' 2>/dev/null || echo "N/A")
        p99_ttft=$(grep "P99 TTFT" "$output_file" | awk '{print $4}' 2>/dev/null || echo "N/A")
        
        echo "- **Successful Requests**: $req_count" >> "$SUMMARY_FILE"
        echo "- **Duration**: ${duration}s" >> "$SUMMARY_FILE"
        echo "- **Throughput**: ${throughput} req/s" >> "$SUMMARY_FILE"
        echo "- **Mean TTFT**: ${mean_ttft}ms" >> "$SUMMARY_FILE"
        echo "- **P99 TTFT**: ${p99_ttft}ms" >> "$SUMMARY_FILE"
        echo "" >> "$SUMMARY_FILE"
    fi
done

cat >> "$SUMMARY_FILE" << EOF

## Files Analyzed
Total JSON files processed: $FILE_COUNT
Analysis files created: $(ls -1 "$FULL_OUTPUT_DIR"/*.txt 2>/dev/null | wc -l)

## Usage
Each analysis file contains detailed performance metrics including:
- Request throughput and success rates
- Time to First Token (TTFT) statistics
- Time per Output Token (TPOT) metrics
- Inter-token Latency (ITL) measurements
- Token generation statistics

## Next Steps
1. Review individual analysis files for detailed metrics
2. Compare performance across different concurrency levels
3. Use the data for performance optimization decisions
4. Generate plots with: \`fib generate-ttft-plot --files $RESULTS_DIR/*.json\`
EOF

echo -e "${GREEN}✅ Summary report saved: $SUMMARY_FILE${NC}"

# Generate metrics JSON for comparison and visualization
generate_metrics_json

echo ""

echo "=== Final Summary ==="
echo "Results directory: $RESULTS_DIR"
echo "Analysis directory: $FULL_OUTPUT_DIR"
echo "Files analyzed: $FILE_COUNT"
echo "Analysis files created: $(ls -1 "$FULL_OUTPUT_DIR"/*.txt 2>/dev/null | wc -l)"
echo "Data points collected: ${#CONCURRENCY_LEVELS[@]}"
echo ""
echo -e "${GREEN}📁 All analysis files are available in: $FULL_OUTPUT_DIR/${NC}"
echo "📄 Summary report: $SUMMARY_FILE"
echo "📊 Metrics JSON: $FULL_OUTPUT_DIR/metrics-data.json"
echo ""
echo "View analysis files with:"
echo "  cat $FULL_OUTPUT_DIR/[test-name]-analysis.txt"
echo ""
echo "Use metrics JSON for:"
echo "  - Custom visualization and plotting"
echo "  - Performance comparison across models"
echo "  - Data analysis with external tools"
echo ""
echo "Generate comparative plots:"
echo "  fib generate-ttft-plot --files $RESULTS_DIR/*.json"
