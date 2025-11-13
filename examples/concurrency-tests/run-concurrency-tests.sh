#!/bin/bash

# CentML Platform Extended Concurrency Test Suite (4 Replicas)
# This script runs comprehensive concurrency tests from low to extreme levels

set -e

echo "=== CentML Platform Extended Concurrency Test Suite ==="
echo "Optimized for 4-replica deployment"
echo "Testing backend: https://honglintest.d691afed.c-09.centml.com"
echo "Model: Qwen/Qwen2.5-VL-7B-Instruct"
echo ""

echo -e "${YELLOW}📝 Timestamp Logging for Manual API Data Collection:${NC}"
echo "Test timestamps will be logged for manual single-replica data collection."
echo "After tests complete, use the timestamps to manually retrieve baseline data from:"
echo "https://api.centml.com/deployments/usage/4186"
echo ""
echo -e "${GREEN}✅ Test timestamps will be logged for manual API data collection${NC}"
echo ""

# Create results directory
mkdir -p concurrency-test-results
cd concurrency-test-results

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Metrics to collect for single-replica comparison
BASELINE_METRICS=(
    "http_requests"
    "request_latency_50_percentile" 
    "request_latency_90_percentile"
    "request_latency_99_percentile"
    "http_requests_by_status"
    "tokens_per_second"
    "error_code"
    "time_to_first_token"
    "gpu"
    "cpu"
    "memory"
)

# Function to log test timestamps for manual API data collection
log_test_timestamps() {
    local start_time=$1
    local end_time=$2
    local test_name=$3
    
    echo -e "${BLUE}📊 Logging timestamps for $test_name...${NC}"
    
    # Create timestamp log file
    local timestamp_file="test-timestamps.log"
    
    # Add header if this is the first test
    if [ ! -f "$timestamp_file" ]; then
        echo "test_name,start_time,end_time,duration_seconds" > "$timestamp_file"
    fi
    
    # Log the test details - simple CSV format for easy processing
    echo "$test_name,$start_time,$end_time,$(($end_time - $start_time))" >> "$timestamp_file"
    
    # Create placeholder files for manual data collection (one per metric)
    mkdir -p baseline-data
    for metric in "${BASELINE_METRICS[@]}"; do
        local metric_file="baseline-data/${metric}.json"
        if [ ! -f "$metric_file" ]; then
            echo "{\"values\": []}" > "$metric_file"
        fi
    done
    
    # Display simple summary to console
    echo "   Start: $start_time ($(date -r $start_time '+%H:%M:%S'))"
    echo "   End: $end_time ($(date -r $end_time '+%H:%M:%S'))" 
    echo "   Duration: $(($end_time - $start_time))s"
    
    echo -e "${GREEN}✅ Logged to $timestamp_file${NC}"
}

# Function to generate a summary report with timestamps for manual data collection
generate_comparison_summary() {
    if [ ! -f "test-timestamps.log" ]; then
        echo -e "${YELLOW}⚠️  No timestamp log found. Skipping comparison summary.${NC}"
        return
    fi
    
    echo -e "${BLUE}📈 Generating comparison summary report...${NC}"
    
    local summary_file="comparison-summary.md"
    cat > "$summary_file" << EOF
# CentML Platform Performance Comparison Report

Generated: $(date)

## Test Configuration
- **4-Replica Deployment**: https://honglintest.d691afed.c-09.centml.com
- **Single Replica Baseline**: Deployment ID $SINGLE_REPLICA_DEPLOYMENT_ID
- **Model**: Qwen/Qwen2.5-VL-7B-Instruct

## Data Files

### 4-Replica Test Results
EOF
    
    # List 4-replica result files
    for file in *-results.json; do
        if [ -f "$file" ]; then
            echo "- $file" >> "$summary_file"
        fi
    done
    
    cat >> "$summary_file" << EOF

### Test Timestamps for Manual API Data Collection
- test-timestamps.log (CSV format: test_name,start_time,end_time,duration_seconds)

### Manual API Data Collection
Use the timestamps in test-timestamps.log to collect single-replica baseline data:
1. Get bearer token from https://app.centml.com (Developer Tools)
2. For each metric, query https://api.centml.com/deployments/usage/4186 for full timeline
3. Paste each metric's API response into the corresponding baseline-data file
4. Use timestamps to extract test-specific sections during analysis

### Metric Files Created (one per metric)
EOF
    
    # List metric files
    for metric in "${BASELINE_METRICS[@]}"; do
        echo "- baseline-data/${metric}.json (paste full timeline API response)" >> "$summary_file"
    done
    
    cat >> "$summary_file" << EOF

## Metrics Collected
EOF
    
    for metric in "${BASELINE_METRICS[@]}"; do
        echo "- $metric" >> "$summary_file"
    done
    
    cat >> "$summary_file" << EOF

## Analysis Commands

### Generate Plots
\`\`\`bash
# Generate TTFT comparison plots
fib generate-ttft-plot --files *-results.json

# Analyze individual test results
fib analyse concurrency-low-results.json
fib analyse concurrency-high-results.json
# ... etc for each test
\`\`\`

### Compare Single-Replica vs 4-Replica Performance
The baseline data files can be used to create comparison charts showing:
- Request throughput scaling (expected ~4x improvement)
- Latency improvements with distributed load
- Resource utilization efficiency per replica

## Files Generated
- Test Results: $(ls -1 *-results.json 2>/dev/null | wc -l) files  
- Timestamp Log: test-timestamps.log (for manual API data collection)
- Scraped Data: $(ls -1 *.json 2>/dev/null | grep -v results | wc -l) files
EOF
    
    echo -e "${GREEN}✅ Comparison summary saved to $summary_file${NC}"
}

# Function to get current timestamp
get_timestamp() {
    date +%s
}

# Function to get test info
get_test_info() {
    local config_file=$1
    case $config_file in
        "concurrency-low.json")
            echo "Low Concurrency|2|5|"
            ;;
        "concurrency-medium.json")
            echo "Medium Concurrency|10|25|"
            ;;
        "concurrency-high.json")
            echo "High Concurrency|25|50|"
            ;;
        "concurrency-extreme.json")
            echo "Extreme Concurrency|50|100|"
            ;;
        "concurrency-stress-test.json")
            echo "Stress Test|100|200|High load test - monitor system resources"
            ;;
        "concurrency-ultra.json")
            echo "Ultra Concurrency|150|300|Very high load - ensure 8 instances are running"
            ;;
        "concurrency-massive.json")
            echo "Massive Concurrency|300|500|Massive load - may overwhelm single-instance backends"
            ;;
        "concurrency-maximum.json")
            echo "Maximum Concurrency|500|750|Maximum sustainable load test"
            ;;
        "concurrency-peak.json")
            echo "Peak Concurrency|750|1000|Peak performance test - risk of timeouts/failures"
            ;;
        "concurrency-burst.json")
            echo "Burst Test|1000|2000|Extreme burst test - very high risk of failures"
            ;;
        *)
            echo "Unknown Test|?|?|"
            ;;
    esac
}

# Function to run test and analyze results
run_test() {
    local config_file=$1
    local test_info=$(get_test_info "$config_file")
    IFS='|' read -r test_name concurrent_limit rps_limit warning_msg <<< "$test_info"
    
    echo -e "${BLUE}--- Running $test_name ---${NC}"
    echo "Max Concurrent: $concurrent_limit | Target RPS: $rps_limit"
    echo "Configuration: $config_file"
    
    if [ ! -z "$warning_msg" ]; then
        echo -e "${YELLOW}⚠️  WARNING: $warning_msg${NC}"
        echo "Continuing automatically..."
    fi
    
    # Capture start time for baseline data collection
    local test_start_time=$(get_timestamp)
    
    # Run benchmark
    echo -e "${GREEN}🚀 Starting test...${NC}"
    if fib benchmark --config-file "../$config_file"; then
        echo -e "${GREEN}✅ Test completed successfully${NC}"
    else
        echo -e "${RED}❌ Test failed or encountered errors${NC}"
        echo "Check the logs above for details"
        echo ""
        return
    fi
    
    # Capture end time for baseline data collection
    local test_end_time=$(get_timestamp)
    
    # Analyze results if output file exists
    local output_file=$(grep '"output_file"' "../$config_file" | cut -d'"' -f4)
    if [ -f "$output_file" ]; then
        echo ""
        echo -e "${BLUE}📊 Results for $test_name:${NC}"
        fib analyse "$output_file"
        echo ""
        echo "-----------------------------------"
        echo ""
    fi
    
    # Log test timestamps for manual API data collection
    log_test_timestamps "$test_start_time" "$test_end_time" "$test_name"
    
    # Small delay between tests
    sleep 3
}

# Test suite functions

run_basic_suite() {
    echo -e "${GREEN}Running Basic Suite...${NC}"
    for test in "concurrency-low.json" "concurrency-medium.json" "concurrency-high.json"; do
        run_test "$test"
    done
}

run_standard_suite() {
    echo -e "${GREEN}Running Standard Suite...${NC}"
    for test in "concurrency-low.json" "concurrency-medium.json" "concurrency-high.json" "concurrency-extreme.json" "concurrency-stress-test.json"; do
        run_test "$test"
    done
}

run_extended_suite() {
    echo -e "${GREEN}Running Extended Suite...${NC}"
    for test in "concurrency-low.json" "concurrency-medium.json" "concurrency-high.json" "concurrency-extreme.json" "concurrency-stress-test.json" "concurrency-ultra.json" "concurrency-massive.json" "concurrency-maximum.json"; do
        run_test "$test"
    done
}

run_full_suite() {
    echo -e "${RED}⚠️  FULL SUITE WARNING ⚠️${NC}"
    echo "This includes PEAK and BURST tests with 750-1000+ concurrent requests"
    echo "These tests may overwhelm your backend and cause failures"
    echo "Recommended only for performance limit testing"
    echo ""
    echo "Running full suite automatically..."
    
    echo -e "${GREEN}Running Full Suite...${NC}"
    for test in "concurrency-low.json" "concurrency-medium.json" "concurrency-high.json" "concurrency-extreme.json" "concurrency-stress-test.json" "concurrency-ultra.json" "concurrency-massive.json" "concurrency-maximum.json" "concurrency-peak.json" "concurrency-burst.json"; do
        run_test "$test"
    done
}

run_high_load_only() {
    echo -e "${YELLOW}Running High-Load Tests Only...${NC}"
    for test in "concurrency-ultra.json" "concurrency-massive.json" "concurrency-maximum.json" "concurrency-peak.json" "concurrency-burst.json"; do
        run_test "$test"
    done
}

run_single_test() {
    local test_name=$1
    if [ -z "$test_name" ]; then
        echo "Available tests:"
        echo "  concurrency-low.json"
        echo "  concurrency-medium.json" 
        echo "  concurrency-high.json"
        echo "  concurrency-extreme.json"
        echo "  concurrency-stress-test.json"
        echo "  concurrency-ultra.json"
        echo "  concurrency-massive.json"
        echo "  concurrency-maximum.json"
        echo "  concurrency-peak.json"
        echo "  concurrency-burst.json"
        echo ""
        echo "Usage: $0 <test-file-name>"
        return 1
    fi
    
    run_test "$test_name"
}

# Auto-run mode - check for command line argument
if [ $# -eq 0 ]; then
    echo "No arguments provided. Running Full Suite automatically..."
    echo ""
    run_full_suite
else
    case $1 in
        1|basic) run_basic_suite ;;
        2|standard) run_standard_suite ;;
        3|extended) run_extended_suite ;;
        4|full) run_full_suite ;;
        5|high-load) run_high_load_only ;;
        *.json) 
            run_single_test "$1"
            ;;
        *) 
            echo "Usage: $0 [suite-type|test-file.json]"
            echo ""
            echo "Suite types:"
            echo "  1/basic     - Basic Suite (Low → High)"
            echo "  2/standard  - Standard Suite (Low → Stress)"
            echo "  3/extended  - Extended Suite (Low → Maximum)"
            echo "  4/full      - Full Suite (All tests including Peak/Burst)"
            echo "  5/high-load - High-Load Only (Ultra → Burst)"
            echo ""
            echo "Single test files:"
            echo "  concurrency-low.json, concurrency-medium.json, etc."
            exit 1
            ;;
    esac
fi

echo ""
echo -e "${BLUE}=== Test Suite Operations Complete ===${NC}"
echo ""

# Generate comparison summary report
generate_comparison_summary

echo ""
echo "=== Final Notes ==="
echo "All results saved in: concurrency-test-results/"
echo ""
if [ -f "test-timestamps.log" ]; then
    echo "📊 Test timestamps logged in: test-timestamps.log (CSV format)"
    echo "   - Contains precise start/end times for each test"
    echo "   - Deployment ID for single-replica data: $SINGLE_REPLICA_DEPLOYMENT_ID"  
    echo "   - Metrics to collect: ${BASELINE_METRICS[*]}"
    echo ""
fi
echo "Generate comparative plots:"
echo "fib generate-ttft-plot --files *.json"
echo ""
echo "Analyze specific results:"
echo "fib analyse <result-file.json>"
echo ""
echo "To collect baseline data, set environment variable:"
echo "export CENTML_API_TOKEN='your_bearer_token_here'"
echo ""
echo "Metric data files to populate:"
echo "  - baseline-data/http_requests.json"
echo "  - baseline-data/request_latency_50_percentile.json"
echo "  - baseline-data/time_to_first_token.json"
echo "  - ... (one file per metric with full timeline data)"