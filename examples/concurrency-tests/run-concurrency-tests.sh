#!/bin/bash

# CentML Platform Extended Concurrency Test Suite (8 Instances)
# This script runs comprehensive concurrency tests from low to extreme levels

set -e

echo "=== CentML Platform Extended Concurrency Test Suite ==="
echo "Optimized for 8-instance deployment"
echo "Testing backend: https://honglintest.d691afed.c-09.centml.com"
echo "Model: Qwen/Qwen2.5-VL-7B-Instruct"
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

echo ""
echo "=== Final Notes ==="
echo "All results saved in: concurrency-test-results/"
echo ""
echo "Generate comparative plots:"
echo "fib generate-ttft-plot --files *.json"
echo ""
echo "Analyze specific results:"
echo "fib analyse <result-file.json>"