# run-concurrency-tests.sh 详细使用指南

## 目录
1. [脚本概述](#脚本概述)
2. [前置条件](#前置条件)
3. [快速开始](#快速开始)
4. [命令行参数详解](#命令行参数详解)
5. [环境变量配置](#环境变量配置)
6. [测试套件类型](#测试套件类型)
7. [配置文件结构](#配置文件结构)
8. [输出结果详解](#输出结果详解)
9. [高级用法](#高级用法)
10. [故障排除](#故障排除)
11. [最佳实践](#最佳实践)
12. [示例场景](#示例场景)

---

## 脚本概述

`run-concurrency-tests.sh` 是一个全面的并发性能测试脚本，用于评估 vLLM 后端在不同并发负载下的性能表现。脚本设计用于测试从低并发到极端高并发的各种场景。

### 主要功能

- **多级并发测试**：从 2 个并发请求到 2000+ 个并发请求
- **自动化测试套件**：预定义的测试套件，覆盖不同负载场景
- **结果分析**：自动运行 `fib analyse` 分析每个测试结果
- **时间戳记录**：记录每个测试的开始/结束时间，用于后续数据分析
- **环境变量支持**：通过环境变量动态覆盖配置
- **详细报告**：生成测试摘要和比较报告

### 脚本工作流程

```
1. 创建结果目录 (concurrency-test-results/)
2. 切换到结果目录
3. 根据参数选择测试套件或单个测试
4. 对每个测试：
   a. 准备配置文件（应用环境变量覆盖）
   b. 记录开始时间
   c. 运行 fib benchmark
   d. 记录结束时间
   e. 分析结果（如果成功）
   f. 记录时间戳
   g. 清理临时文件
5. 生成总结报告
```

---

## 前置条件

### 1. 必需软件

```bash
# 检查 fib 命令是否可用
which fib
# 应该输出类似: /path/to/fib

# 检查 Python 3
python3 --version
# 应该输出: Python 3.x.x

# 检查 bash 版本
bash --version
# 应该输出: GNU bash, version 4.x 或更高
```

### 2. 后端服务

确保你的 vLLM 后端服务正在运行：

```bash
# 检查后端是否可访问
curl http://localhost:8000/health
# 或者
curl http://localhost:8000/v1/models
```

### 3. 文件权限

```bash
# 确保脚本有执行权限
chmod +x run-concurrency-tests.sh

# 确保可以写入结果目录
mkdir -p concurrency-test-results
touch concurrency-test-results/test.txt && rm concurrency-test-results/test.txt
```

### 4. 配置文件

确保所有配置文件存在于脚本目录中：
- `concurrency-low.json`
- `concurrency-medium.json`
- `concurrency-high.json`
- `concurrency-extreme.json`
- `concurrency-stress-test.json`
- `concurrency-ultra.json`
- `concurrency-massive.json`
- `concurrency-maximum.json`
- `concurrency-peak.json`
- `concurrency-burst.json`

---

## 快速开始

### 最简单的用法

```bash
# 运行扩展测试套件（默认行为，跳过 Peak/Burst）
./run-concurrency-tests.sh
```

**注意**：默认仅运行到 Maximum 级别，保持运行时间可控。如需压测 Peak/Burst，请显式执行 `./run-concurrency-tests.sh full`。

### 推荐的第一步

```bash
# 运行基础测试套件（3个测试：低、中、高并发）
./run-concurrency-tests.sh 1
# 或
./run-concurrency-tests.sh basic
```

### 运行单个测试

```bash
# 运行低并发测试
./run-concurrency-tests.sh concurrency-low.json
```

---

## 命令行参数详解

### 语法

```bash
./run-concurrency-tests.sh [suite-type|test-file.json]
```

### 参数类型

#### 1. 测试套件类型（数字或名称）

| 参数 | 等价名称 | 包含的测试 | 说明 |
|------|----------|-----------|------|
| `1` | `basic` | Low → Medium → High | 基础测试，适合快速验证 |
| `2` | `standard` | Low → Medium → High → Extreme → Stress | 标准测试套件 |
| `3` | `extended` | Low → Maximum（不包括 Peak/Burst） | 扩展测试套件 |
| `4` | `full` | 所有测试（包括 Peak/Burst） | 完整测试套件，**警告：可能很耗时** |
| `5` | `high-load` | Ultra → Massive → Maximum → Peak → Burst | 仅高负载测试 |

#### 2. 单个测试文件

直接指定 JSON 配置文件：

```bash
./run-concurrency-tests.sh concurrency-low.json
./run-concurrency-tests.sh concurrency-high.json
```

### 参数示例

```bash
# 使用数字
./run-concurrency-tests.sh 1
./run-concurrency-tests.sh 2
./run-concurrency-tests.sh 3

# 使用名称
./run-concurrency-tests.sh basic
./run-concurrency-tests.sh standard
./run-concurrency-tests.sh extended

# 使用单个测试文件
./run-concurrency-tests.sh concurrency-low.json
./run-concurrency-tests.sh concurrency-medium.json

# 无参数（默认运行扩展套件）
./run-concurrency-tests.sh
```

### 错误处理

如果提供无效参数，脚本会显示使用帮助：

```bash
./run-concurrency-tests.sh invalid
# 输出：
# Usage: ./run-concurrency-tests.sh [suite-type|test-file.json]
# ...
```

---

## 环境变量配置

脚本支持通过环境变量动态覆盖配置文件中的设置，无需修改 JSON 文件。

### 支持的环境变量

| 变量名 | 覆盖的配置项 | 示例值 | 说明 |
|--------|------------|--------|------|
| `FIB_BASE_URL` | `base_url` | `http://localhost:8000` | 后端服务地址 |
| `FIB_BACKEND` | `backend` | `vllm` | 后端类型 |
| `FIB_MODEL` | `model` | `Qwen/Qwen2.5-VL-7B-Instruct` | 模型名称 |

### 使用方法

#### 方法 1：单次设置（当前会话）

```bash
# 设置环境变量并运行
FIB_BASE_URL="http://192.168.1.100:8000" \
FIB_BACKEND="vllm" \
FIB_MODEL="Qwen/Qwen2.5-VL-7B-Instruct" \
./run-concurrency-tests.sh concurrency-low.json
```

#### 方法 2：导出到当前 shell

```bash
# 导出环境变量
export FIB_BASE_URL="http://localhost:8000"
export FIB_BACKEND="vllm"
export FIB_MODEL="Qwen/Qwen2.5-VL-7B-Instruct"

# 运行测试（会使用导出的变量）
./run-concurrency-tests.sh concurrency-low.json

# 取消设置
unset FIB_BASE_URL FIB_BACKEND FIB_MODEL
```

#### 方法 3：在脚本中设置

创建一个包装脚本 `run-tests-custom.sh`：

```bash
#!/bin/bash
export FIB_BASE_URL="http://your-backend:8000"
export FIB_BACKEND="vllm"
export FIB_MODEL="your-model"
./run-concurrency-tests.sh "$@"
```

### 环境变量优先级

环境变量会**覆盖**配置文件中的对应值：

```json
// concurrency-low.json
{
  "base_url": "http://localhost:8000",  // 如果设置了 FIB_BASE_URL，这个值会被覆盖
  ...
}
```

### 实际应用场景

#### 场景 1：测试不同的后端地址

```bash
# 测试本地后端
FIB_BASE_URL="http://localhost:8000" ./run-concurrency-tests.sh basic

# 测试远程后端
FIB_BASE_URL="http://192.168.1.100:8000" ./run-concurrency-tests.sh basic

# 测试生产环境（使用 HTTPS）
FIB_BASE_URL="https://api.example.com" ./run-concurrency-tests.sh basic
```

#### 场景 2：测试不同的模型

```bash
# 测试模型 A
FIB_MODEL="Model-A" ./run-concurrency-tests.sh basic

# 测试模型 B
FIB_MODEL="Model-B" ./run-concurrency-tests.sh basic
```

#### 场景 3：组合使用

```bash
FIB_BASE_URL="http://test-server:8000" \
FIB_BACKEND="vllm" \
FIB_MODEL="Qwen/Qwen2.5-VL-7B-Instruct" \
./run-concurrency-tests.sh standard
```

---

## 测试套件类型

### 1. Basic Suite (基础套件)

**命令**：`./run-concurrency-tests.sh 1` 或 `./run-concurrency-tests.sh basic`

**包含测试**：
- `concurrency-low.json` - 低并发（2 并发，5 RPS）
- `concurrency-medium.json` - 中等并发（10 并发，25 RPS）
- `concurrency-high.json` - 高并发（25 并发，50 RPS）

**适用场景**：
- 快速验证后端是否正常工作
- 开发环境的基本测试
- 首次运行脚本时的验证

**预计时间**：10-30 分钟（取决于后端性能）

### 2. Standard Suite (标准套件)

**命令**：`./run-concurrency-tests.sh 2` 或 `./run-concurrency-tests.sh standard`

**包含测试**：
- Basic Suite 的所有测试
- `concurrency-extreme.json` - 极端并发（50 并发，100 RPS）
- `concurrency-stress-test.json` - 压力测试（100 并发，200 RPS）

**适用场景**：
- 常规性能测试
- CI/CD 流水线集成
- 发布前的标准验证

**预计时间**：30-90 分钟

### 3. Extended Suite (扩展套件)

**命令**：`./run-concurrency-tests.sh 3` 或 `./run-concurrency-tests.sh extended`

**包含测试**：
- Standard Suite 的所有测试
- `concurrency-ultra.json` - 超高并发（150 并发，300 RPS）
- `concurrency-massive.json` - 大规模并发（300 并发，500 RPS）
- `concurrency-maximum.json` - 最大并发（500 并发，750 RPS）

**适用场景**：
- 深度性能分析
- 容量规划
- 性能基准测试

**预计时间**：1-3 小时

### 4. Full Suite (完整套件)

**命令**：`./run-concurrency-tests.sh 4` 或 `./run-concurrency-tests.sh full`

**包含测试**：
- Extended Suite 的所有测试
- `concurrency-peak.json` - 峰值测试（750 并发，1000 RPS）
- `concurrency-burst.json` - 突发测试（1000 并发，2000 RPS）

**⚠️ 警告**：
- 这些测试可能会压垮后端服务
- 可能导致超时和失败
- 仅用于极限性能测试

**适用场景**：
- 压力测试和极限测试
- 系统容量上限测试
- 故障恢复测试

**预计时间**：2-6 小时（可能因失败而更长）

### 5. High-Load Only (仅高负载)

**命令**：`./run-concurrency-tests.sh 5` 或 `./run-concurrency-tests.sh high-load`

**包含测试**：
- `concurrency-ultra.json`
- `concurrency-massive.json`
- `concurrency-maximum.json`
- `concurrency-peak.json`
- `concurrency-burst.json`

**适用场景**：
- 跳过低负载测试，直接测试高负载场景
- 快速验证高并发性能
- 节省时间的高负载专项测试

**预计时间**：1-4 小时

### 测试套件选择建议

| 场景 | 推荐套件 | 原因 |
|------|---------|------|
| 首次使用 | Basic (1) | 快速验证，确保一切正常 |
| 日常开发 | Standard (2) | 平衡测试覆盖和时间 |
| 性能优化 | Extended (3) | 全面的性能分析 |
| 发布前验证 | Standard (2) 或 Extended (3) | 确保性能符合要求 |
| 容量规划 | Extended (3) | 了解系统容量 |
| 压力测试 | Full (4) | 测试极限情况 |
| 快速高负载测试 | High-Load (5) | 跳过低负载，节省时间 |

---

## 配置文件结构

### 配置文件位置

配置文件位于脚本所在目录，命名格式：`concurrency-<level>.json`

### 配置文件示例

```json
{
    "backend": "vllm",
    "base_url": "http://localhost:8000",
    "endpoint": "/v1/completions",
    "model": "Qwen/Qwen2.5-VL-7B-Instruct",
    "seed": 123123,
    "tokenizer": "Qwen/Qwen2.5-VL-7B-Instruct",
    "dataset_name": "sharegpt",
    "num_of_req": 250,
    "max_concurrent": 2,
    "request_rate": 5,
    "request_distribution": ["poisson", 5],
    "temperature": 0.0,
    "disable_stream": false,
    "num_validation_reqs": 2,
    "output_file": "concurrency-low-results.json"
}
```

### 配置项详解

#### 必需配置项

| 配置项 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| `backend` | string | 后端类型 | `"vllm"` |
| `base_url` | string | 后端服务地址 | `"http://localhost:8000"` |
| `model` | string | 模型名称 | `"Qwen/Qwen2.5-VL-7B-Instruct"` |
| `output_file` | string | 结果文件名 | `"concurrency-low-results.json"` |

#### 性能相关配置

| 配置项 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| `num_of_req` | integer | 总请求数 | `250` |
| `max_concurrent` | integer | 最大并发数 | `2` |
| `request_rate` | integer | 目标请求速率（RPS） | `5` |
| `request_distribution` | array | 请求分布类型和参数 | `["poisson", 5]` |

**请求分布类型**：
- `["poisson", lambda]` - 泊松分布，lambda 为平均速率
- `["uniform", min, max]` - 均匀分布
- `["exponential", rate]` - 指数分布

#### 模型相关配置

| 配置项 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| `tokenizer` | string | Tokenizer 名称 | `"Qwen/Qwen2.5-VL-7B-Instruct"` |
| `temperature` | float | 生成温度 | `0.0` (确定性) 到 `1.0` (随机性) |
| `disable_stream` | boolean | 是否禁用流式输出 | `false` |

#### 数据集配置

| 配置项 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| `dataset_name` | string | 数据集名称 | `"sharegpt"` |
| `num_validation_reqs` | integer | 验证请求数 | `2` |

#### 其他配置

| 配置项 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| `seed` | integer | 随机种子 | `123123` |
| `endpoint` | string | API 端点 | `"/v1/completions"` |

### 测试级别配置对比

| 测试级别 | max_concurrent | request_rate | num_of_req | 说明 |
|----------|---------------|--------------|------------|------|
| Low | 2 | 5 | 250 | 低负载 |
| Medium | 10 | 25 | 1250 | 中等负载 |
| High | 25 | 50 | 2500 | 高负载 |
| Extreme | 50 | 100 | 5000 | 极端负载 |
| Stress | 100 | 200 | 10000 | 压力测试 |
| Ultra | 150 | 300 | 15000 | 超高负载 |
| Massive | 300 | 500 | 30000 | 大规模负载 |
| Maximum | 500 | 750 | 50000 | 最大负载 |
| Peak | 750 | 1000 | 75000 | 峰值测试 |
| Burst | 1000 | 2000 | 100000 | 突发测试 |

### 自定义配置文件

你可以创建自己的配置文件：

```bash
# 创建自定义配置
cat > my-custom-test.json << 'EOF'
{
    "backend": "vllm",
    "base_url": "http://localhost:8000",
    "endpoint": "/v1/completions",
    "model": "Qwen/Qwen2.5-VL-7B-Instruct",
    "seed": 123123,
    "tokenizer": "Qwen/Qwen2.5-VL-7B-Instruct",
    "dataset_name": "sharegpt",
    "num_of_req": 100,
    "max_concurrent": 5,
    "request_rate": 10,
    "request_distribution": ["poisson", 10],
    "temperature": 0.0,
    "disable_stream": false,
    "num_validation_reqs": 2,
    "output_file": "my-custom-results.json"
}
EOF

# 运行自定义测试
./run-concurrency-tests.sh my-custom-test.json
```

**注意**：自定义配置文件需要包含 `get_test_info` 函数中定义的测试名称，或者脚本会显示 "Unknown Test"。

---

## 输出结果详解

### 结果目录结构

运行脚本后，会在 `concurrency-test-results/` 目录中生成以下内容：

```
concurrency-test-results/
├── concurrency-low-results.json          # 测试结果文件
├── concurrency-medium-results.json
├── concurrency-high-results.json
├── ... (其他测试结果)
├── test-timestamps.log                    # 时间戳日志
├── comparison-summary.md                  # 比较摘要报告
└── baseline-data/                         # 基线数据目录
    ├── http_requests.json
    ├── request_latency_50_percentile.json
    ├── request_latency_90_percentile.json
    ├── request_latency_99_percentile.json
    ├── http_requests_by_status.json
    ├── tokens_per_second.json
    ├── error_code.json
    ├── time_to_first_token.json
    ├── gpu.json
    ├── cpu.json
    └── memory.json
```

### 1. 测试结果文件 (`*-results.json`)

每个测试会生成一个 JSON 结果文件，包含详细的性能指标。

**文件位置**：`concurrency-test-results/concurrency-<level>-results.json`

**内容示例**：
```json
{
  "successful_requests": 250,
  "failed_requests": 0,
  "total_requests": 250,
  "benchmark_duration": 51.47,
  "request_throughput": 4.86,
  "input_token_throughput": 1240.36,
  "output_token_throughput": 64.13,
  "ttft_stats": {
    "mean": 3.85,
    "median": 3.55,
    "p99": 13.98
  },
  ...
}
```

**使用方法**：
```bash
# 分析单个结果文件
fib analyse concurrency-test-results/concurrency-low-results.json

# 生成对比图表
fib generate-ttft-plot --files concurrency-test-results/*-results.json
```

### 2. 时间戳日志 (`test-timestamps.log`)

CSV 格式的日志文件，记录每个测试的开始和结束时间。

**格式**：
```csv
test_name,start_time,end_time,duration_seconds
Low Concurrency,1701234567,1701234618,51
Medium Concurrency,1701234621,1701234750,129
```

**用途**：
- 与监控系统的时间序列数据对齐
- 手动收集基线数据时的时间范围参考
- 性能分析的时间窗口

**使用方法**：
```bash
# 查看时间戳日志
cat concurrency-test-results/test-timestamps.log

# 提取特定测试的时间范围
grep "Low Concurrency" concurrency-test-results/test-timestamps.log
```

### 3. 比较摘要报告 (`comparison-summary.md`)

Markdown 格式的摘要报告，包含：
- 测试配置信息
- 生成的文件列表
- 分析命令示例
- 数据收集说明

**查看方法**：
```bash
cat concurrency-test-results/comparison-summary.md
# 或
less concurrency-test-results/comparison-summary.md
```

### 4. 基线数据目录 (`baseline-data/`)

包含占位符 JSON 文件，用于手动收集基线数据。

**文件列表**：
- `http_requests.json` - HTTP 请求数
- `request_latency_50_percentile.json` - 50% 分位延迟
- `request_latency_90_percentile.json` - 90% 分位延迟
- `request_latency_99_percentile.json` - 99% 分位延迟
- `http_requests_by_status.json` - 按状态分类的请求
- `tokens_per_second.json` - 每秒 token 数
- `error_code.json` - 错误代码
- `time_to_first_token.json` - 首 token 时间
- `gpu.json` - GPU 使用率
- `cpu.json` - CPU 使用率
- `memory.json` - 内存使用率

**使用方法**：
1. 从监控系统（如 Prometheus、Grafana）导出时间序列数据
2. 将数据粘贴到对应的 JSON 文件中
3. 使用时间戳日志对齐时间范围

### 控制台输出

脚本运行时会显示：

1. **测试进度**：
   ```
   --- Running Low Concurrency ---
   Max Concurrent: 2 | Target RPS: 5
   Configuration: concurrency-low.json
   🚀 Starting test...
   ```

2. **测试结果摘要**：
   ```
   ✅ Test completed successfully
   📊 Expected output file: concurrency-low-results.json
   📊 Results for Low Concurrency:
   [fib analyse 的输出]
   ```

3. **时间戳记录**：
   ```
   📊 Logging timestamps for Low Concurrency...
      Start: 1701234567 (19:23:45)
      End: 1701234618 (19:24:18)
      Duration: 51s
   ✅ Logged to test-timestamps.log
   ```

4. **最终摘要**：
   ```
   === Test Suite Operations Complete ===
   All results saved in: concurrency-test-results/
   ```

---

## 高级用法

### 1. 后台运行测试

对于长时间运行的测试套件，可以后台运行：

```bash
# 后台运行并保存输出
nohup ./run-concurrency-tests.sh extended > test-output.log 2>&1 &

# 查看进程
ps aux | grep run-concurrency-tests

# 查看输出
tail -f test-output.log

# 查看实时进度
tail -f concurrency-test-results/test-timestamps.log
```

### 2. 使用 screen 或 tmux

```bash
# 使用 screen
screen -S concurrency-tests
./run-concurrency-tests.sh extended
# 按 Ctrl+A 然后 D 分离会话

# 重新连接
screen -r concurrency-tests

# 使用 tmux
tmux new -s concurrency-tests
./run-concurrency-tests.sh extended
# 按 Ctrl+B 然后 D 分离会话

# 重新连接
tmux attach -t concurrency-tests
```

### 3. 并行运行多个测试套件

```bash
# 在不同终端或使用不同配置运行多个测试
# 终端 1
FIB_BASE_URL="http://server1:8000" ./run-concurrency-tests.sh basic &

# 终端 2
FIB_BASE_URL="http://server2:8000" ./run-concurrency-tests.sh basic &

# 等待所有后台任务完成
wait
```

### 4. 自定义测试顺序

创建自定义脚本：

```bash
#!/bin/bash
# custom-test-order.sh

# 运行特定顺序的测试
./run-concurrency-tests.sh concurrency-low.json
sleep 60  # 等待系统稳定
./run-concurrency-tests.sh concurrency-high.json
sleep 60
./run-concurrency-tests.sh concurrency-extreme.json
```

### 5. 条件执行

```bash
# 只在后端可用时运行
if curl -f http://localhost:8000/health > /dev/null 2>&1; then
    ./run-concurrency-tests.sh basic
else
    echo "Backend not available"
    exit 1
fi
```

### 6. 结果后处理

```bash
#!/bin/bash
# post-process-results.sh

RESULTS_DIR="concurrency-test-results"

# 分析所有结果
for result_file in "$RESULTS_DIR"/*-results.json; do
    echo "Analyzing $result_file"
    fib analyse "$result_file" > "${result_file%.json}-analysis.txt"
done

# 生成对比图表
cd "$RESULTS_DIR"
fib generate-ttft-plot --files *-results.json

# 提取关键指标
grep "Mean TTFT" *-analysis.txt > ttft-summary.txt
```

### 7. 集成到 CI/CD

```yaml
# .github/workflows/performance-test.yml
name: Performance Tests

on:
  schedule:
    - cron: '0 2 * * *'  # 每天凌晨 2 点
  workflow_dispatch:

jobs:
  performance-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.9'
      - name: Install dependencies
        run: pip install -r requirements.txt
      - name: Run basic tests
        env:
          FIB_BASE_URL: ${{ secrets.TEST_BACKEND_URL }}
        run: ./run-concurrency-tests.sh basic
      - name: Upload results
        uses: actions/upload-artifact@v2
        with:
          name: test-results
          path: concurrency-test-results/
```

---

## 故障排除

### 常见问题

#### 1. 脚本无法执行

**错误**：`Permission denied`

**解决方案**：
```bash
chmod +x run-concurrency-tests.sh
```

#### 2. fib 命令未找到

**错误**：`fib: command not found`

**解决方案**：
```bash
# 检查 fib 是否安装
which fib

# 如果未安装，安装 flexible-inference-bench
pip install flexible-inference-bench

# 或使用完整路径
/path/to/fib benchmark --config-file ...
```

#### 3. Python 3 未找到

**错误**：`python3: command not found`

**解决方案**：
```bash
# 检查 Python 3
python3 --version

# 如果没有，安装 Python 3
# macOS
brew install python3

# Ubuntu/Debian
sudo apt-get install python3

# 或使用 python（如果指向 Python 3）
# 修改脚本中的 python3 为 python
```

#### 4. 后端连接失败

**错误**：`Connection refused` 或 `Failed to connect`

**解决方案**：
```bash
# 检查后端是否运行
curl http://localhost:8000/health

# 检查端口是否被占用
lsof -i :8000

# 检查防火墙设置
# 如果使用远程后端，确保网络可达

# 使用正确的 base_url
FIB_BASE_URL="http://correct-host:8000" ./run-concurrency-tests.sh basic
```

#### 5. 结果文件未生成

**错误**：`Warning: Output file 'xxx-results.json' not found`

**可能原因**：
- 测试失败但脚本继续执行
- 文件创建在错误的位置
- 权限问题

**解决方案**：
```bash
# 检查当前目录
pwd
# 应该在 concurrency-test-results/ 目录中

# 检查文件是否在其他位置
find . -name "*-results.json"

# 检查权限
ls -la concurrency-test-results/

# 手动运行单个测试查看详细错误
fib benchmark --config-file concurrency-low.json
```

#### 6. 测试超时

**错误**：测试运行时间过长或超时

**解决方案**：
```bash
# 检查后端性能
curl -w "@-" -o /dev/null -s http://localhost:8000/health <<'EOF'
     time_namelookup:  %{time_namelookup}\n
        time_connect:  %{time_connect}\n
     time_appconnect:  %{time_appconnect}\n
    time_pretransfer:  %{time_pretransfer}\n
       time_redirect:  %{time_redirect}\n
  time_starttransfer:  %{time_starttransfer}\n
                     ----------\n
          time_total:  %{time_total}\n
EOF

# 降低并发数（修改配置文件）
# 或使用较低负载的测试套件
./run-concurrency-tests.sh basic  # 而不是 full
```

#### 7. 内存不足

**错误**：`Out of memory` 或系统变慢

**解决方案**：
```bash
# 检查系统资源
free -h  # Linux
vm_stat  # macOS

# 减少并发数
# 修改配置文件中的 max_concurrent

# 使用较低负载的测试
./run-concurrency-tests.sh basic
```

#### 8. 临时文件未清理

**错误**：`/tmp` 目录中有大量临时文件

**解决方案**：
```bash
# 手动清理
rm -f /tmp/tmp.*  # 注意：这会删除所有临时文件

# 或只清理脚本创建的临时文件
# 脚本会在测试完成后自动清理，但如果脚本被中断，可能需要手动清理
```

### 调试技巧

#### 1. 启用详细输出

修改脚本，添加 `set -x`：

```bash
#!/bin/bash
set -e
set -x  # 添加这行以显示执行的每个命令
```

#### 2. 检查配置文件

```bash
# 验证 JSON 格式
python3 -m json.tool concurrency-low.json

# 查看实际使用的配置（临时文件）
# 在脚本中添加调试输出
echo "Using config: $prepared_config"
cat "$prepared_config"
```

#### 3. 单独测试组件

```bash
# 测试 prepare_config 函数
source run-concurrency-tests.sh
prepare_config concurrency-low.json

# 测试 fib benchmark
fib benchmark --config-file concurrency-low.json

# 测试 fib analyse
fib analyse concurrency-test-results/concurrency-low-results.json
```

#### 4. 检查日志

```bash
# 查看脚本输出
./run-concurrency-tests.sh basic 2>&1 | tee test.log

# 分析日志
grep -i error test.log
grep -i warning test.log
grep -i "test failed" test.log
```

---

## 最佳实践

### 1. 测试前准备

```bash
# ✅ 检查后端可用性
curl http://localhost:8000/health

# ✅ 检查系统资源
free -h  # 或 vm_stat (macOS)

# ✅ 清理旧结果（可选）
rm -rf concurrency-test-results/

# ✅ 确保有足够的磁盘空间
df -h
```

### 2. 渐进式测试

```bash
# ✅ 从低负载开始
./run-concurrency-tests.sh basic

# ✅ 检查结果
ls -lh concurrency-test-results/*-results.json

# ✅ 如果成功，逐步增加负载
./run-concurrency-tests.sh standard
./run-concurrency-tests.sh extended
```

### 3. 结果管理

```bash
# ✅ 为每次测试运行创建时间戳目录
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "results_$TIMESTAMP"
mv concurrency-test-results "results_$TIMESTAMP/"

# ✅ 或使用有意义的名称
mv concurrency-test-results "results_baseline_$(date +%Y%m%d)"
```

### 4. 监控和记录

```bash
# ✅ 同时监控系统资源
# 终端 1：运行测试
./run-concurrency-tests.sh extended

# 终端 2：监控资源
watch -n 1 'free -h && echo "---" && ps aux | grep fib'

# ✅ 记录环境信息
cat > concurrency-test-results/environment.txt << EOF
Date: $(date)
Hostname: $(hostname)
Backend: $FIB_BASE_URL
Model: $FIB_MODEL
Git commit: $(git rev-parse HEAD)
EOF
```

### 5. 结果分析

```bash
# ✅ 立即分析结果
cd concurrency-test-results
for file in *-results.json; do
    echo "=== $file ==="
    fib analyse "$file"
    echo ""
done

# ✅ 生成对比图表
fib generate-ttft-plot --files *-results.json

# ✅ 提取关键指标
grep -h "Mean TTFT\|P99 TTFT\|Request throughput" *-results.json
```

### 6. 错误处理

```bash
# ✅ 使用 trap 确保清理
trap 'rm -f /tmp/tmp.*; exit' INT TERM EXIT

# ✅ 检查测试是否成功
if [ $? -eq 0 ]; then
    echo "Tests completed successfully"
else
    echo "Tests failed, check logs"
    exit 1
fi
```

### 7. 性能优化

```bash
# ✅ 避免在测试期间运行其他负载
# ✅ 使用专用测试环境
# ✅ 确保网络稳定
# ✅ 预热后端（运行少量请求）
```

---

## 示例场景

### 场景 1：首次使用脚本

```bash
# 1. 检查环境
which fib
python3 --version
curl http://localhost:8000/health

# 2. 运行基础测试验证
./run-concurrency-tests.sh basic

# 3. 检查结果
ls -lh concurrency-test-results/
cat concurrency-test-results/test-timestamps.log

# 4. 如果成功，运行标准测试
./run-concurrency-tests.sh standard
```

### 场景 2：测试不同后端配置

```bash
# 测试配置 A
FIB_BASE_URL="http://backend-a:8000" \
./run-concurrency-tests.sh standard
mv concurrency-test-results results_backend_a

# 测试配置 B
FIB_BASE_URL="http://backend-b:8000" \
./run-concurrency-tests.sh standard
mv concurrency-test-results results_backend_b

# 对比结果
diff <(fib analyse results_backend_a/concurrency-high-results.json) \
     <(fib analyse results_backend_b/concurrency-high-results.json)
```

### 场景 3：性能回归测试

```bash
# 基线测试
git checkout main
./run-concurrency-tests.sh standard
mv concurrency-test-results results_baseline

# 新版本测试
git checkout feature-branch
./run-concurrency-tests.sh standard
mv concurrency-test-results results_feature

# 对比分析
# 使用 analyze-results.sh 或手动对比
```

### 场景 4：容量规划

```bash
# 逐步增加负载，找到系统上限
./run-concurrency-tests.sh basic      # 基线
./run-concurrency-tests.sh standard   # 中等负载
./run-concurrency-tests.sh extended   # 高负载

# 分析结果，确定：
# - 最大支持的并发数
# - 性能开始下降的点
# - 系统瓶颈
```

### 场景 5：CI/CD 集成

```bash
#!/bin/bash
# ci-performance-test.sh

set -e

# 设置环境
export FIB_BASE_URL="${TEST_BACKEND_URL:-http://localhost:8000}"

# 运行快速测试
./run-concurrency-tests.sh basic

# 检查结果
if [ ! -f "concurrency-test-results/concurrency-low-results.json" ]; then
    echo "ERROR: Test results not generated"
    exit 1
fi

# 提取关键指标
MEAN_TTFT=$(fib analyse concurrency-test-results/concurrency-low-results.json | \
            grep "Mean TTFT" | awk '{print $4}')

# 检查性能阈值
if (( $(echo "$MEAN_TTFT > 100" | bc -l) )); then
    echo "WARNING: Mean TTFT ($MEAN_TTFT ms) exceeds threshold (100 ms)"
    exit 1
fi

echo "Performance test passed: Mean TTFT = $MEAN_TTFT ms"
```

---

## 总结

`run-concurrency-tests.sh` 是一个功能强大的并发性能测试工具，支持：

- ✅ 多种测试套件（从基础到完整）
- ✅ 灵活的环境变量配置
- ✅ 自动结果分析和报告生成
- ✅ 时间戳记录用于数据对齐
- ✅ 详细的错误处理和调试信息

**推荐工作流程**：
1. 首次使用：运行 `basic` 套件验证环境
2. 日常测试：使用 `standard` 套件
3. 深度分析：使用 `extended` 套件
4. 极限测试：使用 `full` 套件（谨慎使用）

**关键提示**：
- 始终从低负载开始测试
- 确保后端服务稳定运行
- 监控系统资源使用情况
- 保存和备份测试结果
- 使用环境变量灵活配置

如有问题，请参考故障排除部分或检查脚本输出中的错误信息。
