#!/bin/bash

# Diagnostic script to identify why test results are not being generated

echo "=== 诊断测试结果未生成的问题 ==="
echo ""

# Check if results directory exists
RESULTS_DIR="concurrency-test-results"
if [ -d "$RESULTS_DIR" ]; then
    echo "✅ 结果目录存在: $RESULTS_DIR"
    echo "   目录内容:"
    ls -la "$RESULTS_DIR" | head -10
    echo ""
    
    # Count result files
    RESULT_FILES=$(find "$RESULTS_DIR" -name "*-results.json" -type f 2>/dev/null | wc -l)
    echo "   找到的结果文件数量: $RESULT_FILES"
    if [ $RESULT_FILES -gt 0 ]; then
        echo "   结果文件列表:"
        find "$RESULTS_DIR" -name "*-results.json" -type f | head -10
    fi
    echo ""
else
    echo "❌ 结果目录不存在: $RESULTS_DIR"
    echo ""
fi

# Check if fib command is available
echo "检查 fib 命令:"
if command -v fib &> /dev/null; then
    echo "✅ fib 命令可用: $(which fib)"
    echo "   fib 版本信息:"
    fib --version 2>&1 | head -3 || echo "   (无法获取版本信息)"
else
    echo "❌ fib 命令不可用"
fi
echo ""

# Check configuration files
echo "检查配置文件:"
CONFIG_FILES=$(ls -1 *.json 2>/dev/null | grep -v results | grep -v "^concurrency-low-results.json$" || true)
if [ -n "$CONFIG_FILES" ]; then
    echo "✅ 找到配置文件:"
    echo "$CONFIG_FILES" | head -5
    echo ""
    
    # Check first config file
    FIRST_CONFIG=$(echo "$CONFIG_FILES" | head -1)
    if [ -n "$FIRST_CONFIG" ]; then
        echo "检查配置文件 '$FIRST_CONFIG':"
        if [ -f "$FIRST_CONFIG" ]; then
            echo "✅ 文件存在"
            echo "   output_file 设置:"
            grep '"output_file"' "$FIRST_CONFIG" || echo "   (未找到 output_file)"
            echo "   base_url 设置:"
            grep '"base_url"' "$FIRST_CONFIG" || echo "   (未找到 base_url)"
        else
            echo "❌ 文件不存在"
        fi
    fi
else
    echo "❌ 未找到配置文件"
fi
echo ""

# Check backend connectivity (if base_url is set)
echo "检查后端连接性:"
if [ -f "concurrency-low.json" ]; then
    BASE_URL=$(grep '"base_url"' concurrency-low.json | cut -d'"' -f4)
    if [ -n "$BASE_URL" ]; then
        echo "   后端URL: $BASE_URL"
        # Extract host and port
        if [[ "$BASE_URL" =~ http://([^:/]+)(:([0-9]+))? ]]; then
            HOST="${BASH_REMATCH[1]}"
            PORT="${BASH_REMATCH[3]:-80}"
            echo "   尝试连接到 $HOST:$PORT..."
            if timeout 2 bash -c "echo > /dev/tcp/$HOST/$PORT" 2>/dev/null; then
                echo "   ✅ 后端可连接"
            else
                echo "   ❌ 后端不可连接 (这可能是问题所在)"
                echo "   请检查后端服务是否正在运行"
            fi
        fi
    fi
fi
echo ""

# Check script syntax
echo "检查脚本语法:"
if [ -f "run-concurrency-tests.sh" ]; then
    if bash -n run-concurrency-tests.sh 2>&1; then
        echo "✅ 脚本语法正确"
    else
        echo "❌ 脚本语法错误:"
        bash -n run-concurrency-tests.sh 2>&1
    fi
else
    echo "❌ 脚本文件不存在"
fi
echo ""

# Summary
echo "=== 诊断总结 ==="
echo ""
echo "可能的问题:"
echo "1. 后端服务未运行 - 检查 base_url 设置并确保后端服务正在运行"
echo "2. 测试未执行 - 检查是否运行了 run-concurrency-tests.sh"
echo "3. 测试失败 - 检查上面的错误信息"
echo "4. 输出文件路径问题 - 检查配置文件中的 output_file 设置"
echo ""
echo "建议的修复步骤:"
echo "1. 确保后端服务正在运行: $BASE_URL"
echo "2. 手动运行单个测试: fib benchmark --config-file concurrency-low.json"
echo "3. 检查输出文件是否在正确的位置创建"
echo "4. 查看 run-concurrency-tests.sh 的详细输出"
