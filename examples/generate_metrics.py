#!/usr/bin/env python3
"""Convert concurrency test metrics JSON exports into raw metrics CSV rows.

Usage:
    # Write to file
    python generate_raw_metrics_csv.py --endpoint lepton-vllm-2xa100-sxm4 \\
        --results-dir concurrency-tests-lepton-vllm-2x-a100-sxm4/ \\
        --output raw_metrics.csv
    
    # Write to stdout (for piping or appending)
    python generate_raw_metrics_csv.py --endpoint lepton-vllm-2xa100-sxm4 \\
        --results-dir concurrency-tests-lepton-vllm-2x-a100-sxm4/

Note: --results-dir should point to the TOP-LEVEL test directory (e.g. 'concurrency-tests-lepton-vllm-2x-a100-sxm4/'),
      NOT the subdirectory 'concurrency-test-results/'.
"""

# Standard library imports
import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Dict, List, Optional, Sequence


CSV_HEADER = [
    "endpoint",
    "concurrency",
    "mean_ttft_ms",
    "p99_ttft_ms",
    "input_tok_s",
    "output_tok_s",
    "mean_tpot_ms",
    "p99_tpot_ms",
    "mean_itl_ms",
    "p99_itl_ms",
    "successful_requests",
    "duration_s",
]

METRIC_FIELD_MAP = [
    ("mean_ttft_ms", "mean_ttft"),
    ("p99_ttft_ms", "p99_ttft"),
    ("input_tok_s", "input_token_throughput"),
    ("output_tok_s", "output_token_throughput"),
    ("mean_tpot_ms", "mean_tpot"),
    ("p99_tpot_ms", "p99_tpot"),
    ("mean_itl_ms", "mean_itl"),
    ("p99_itl_ms", "p99_itl"),
    ("successful_requests", "successful_requests"),
    ("duration_s", "duration"),
]

MetricsData = Dict[str, List[List[float]]]
CsvRow = List[str]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate a CSV that mirrors 'honglin performance analysis - raw_metrics.csv' "
            "from a concurrency test metrics JSON export."
        )
    )
    parser.add_argument(
        "--endpoint",
        required=True,
        help="Endpoint name to include in the CSV output (e.g. 'lepton-vllm-2xa100-sxm4').",
    )
    parser.add_argument(
        "--results-dir",
        required=True,
        help=(
            "Path to the TOP-LEVEL test directory (e.g. 'concurrency-tests-lepton-vllm-2x-a100-sxm4/', "
            "NOT 'concurrency-tests-lepton-vllm-2x-a100-sxm4/concurrency-test-results/'). "
            "The script will look for 'concurrency-test-results/analysis-exports/metrics-data.json' inside."
        ),
    )
    parser.add_argument(
        "--output",
        help=(
            "Optional output CSV file path. If omitted, CSV is printed to stdout. "
            "Example: 'raw_metrics_output.csv'"
        ),
    )
    parser.add_argument(
        "--metrics-file",
        help=(
            "Optional direct path to metrics-data.json. When omitted, the script looks for "
            "'concurrency-test-results/analysis-exports/metrics-data.json' inside --results-dir."
        ),
    )
    return parser.parse_args()


def resolve_metrics_path(results_dir: Path, metrics_override: Optional[Path]) -> Path:
    """
    Resolve the path to metrics-data.json.
    
    Args:
        results_dir: Top-level test directory (e.g. 'concurrency-tests-lepton-vllm-2x-a100-sxm4/').
        metrics_override: Optional direct path to metrics-data.json.
    
    Returns:
        Path to metrics-data.json. Defaults to '<results_dir>/concurrency-test-results/analysis-exports/metrics-data.json'.
    """
    if metrics_override is not None:
        return metrics_override
    return results_dir / "concurrency-test-results" / "analysis-exports" / "metrics-data.json"


def sanitize_endpoint(endpoint: str) -> str:
    safe_chars = []
    for char in endpoint.lower():
        if char.isalnum() or char in {"-", "_"}:
            safe_chars.append(char)
        else:
            safe_chars.append("-")
    return "".join(safe_chars).strip("-") or "endpoint"


def default_output_path(endpoint: str) -> Path:
    return Path(f"{sanitize_endpoint(endpoint)}-raw-metrics.csv")


def load_metrics_data(metrics_path: Path) -> MetricsData:
    """
    Load and validate metrics-data.json.
    
    Args:
        metrics_path: Path to metrics-data.json file.
    
    Returns:
        Dict mapping metric names to [[concurrency, value], ...] arrays.
    
    Raises:
        FileNotFoundError: If metrics file doesn't exist.
        ValueError: If JSON is invalid.
        KeyError: If 'metrics' section is missing.
    """
    try:
        with metrics_path.open("r", encoding="utf-8") as handle:
            payload = json.load(handle)
    except FileNotFoundError as exc:
        raise FileNotFoundError(f"Metrics file not found: {metrics_path}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in metrics file {metrics_path}: {exc}") from exc

    metrics_section = payload.get("metrics")
    if metrics_section is None:
        raise KeyError(f"'metrics' section missing in {metrics_path}")
    return metrics_section


def format_number(value: float) -> str:
    """
    Format numeric value to match original CSV formatting.
    
    Strips trailing zeros and decimal point for cleaner output.
    
    Args:
        value: Numeric value to format.
    
    Returns:
        Formatted string representation.
    """
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        if value.is_integer():
            return str(int(value))
        formatted = f"{value:.6f}".rstrip("0").rstrip(".")
        return formatted or "0"
    return str(value)


def build_rows(endpoint: str, metrics_data: MetricsData) -> List[CsvRow]:
    """
    Build CSV rows from metrics data.
    
    Aggregates all metrics by concurrency level and produces rows matching the CSV_HEADER format.
    
    Args:
        endpoint: Endpoint name to populate in the first column.
        metrics_data: Dict of metric arrays from metrics-data.json.
    
    Returns:
        List of CSV rows (each row is a list of strings).
    
    Raises:
        KeyError: If required metric is missing.
        ValueError: If metric data is malformed or incomplete.
    """
    concurrency_map: Dict[int, Dict[str, float]] = {}

    # Aggregate all metrics by concurrency level
    for _, metric_key in METRIC_FIELD_MAP:
        metric_points = metrics_data.get(metric_key)
        if metric_points is None:
            raise KeyError(f"Metric '{metric_key}' missing from metrics JSON.")

        for point in metric_points:
            if not isinstance(point, Sequence) or len(point) != 2:
                raise ValueError(f"Metric '{metric_key}' has malformed entry: {point}")
            concurrency_raw, metric_value = point
            concurrency_level = int(concurrency_raw)
            bucket = concurrency_map.setdefault(concurrency_level, {})
            bucket[metric_key] = metric_value

    # Build rows sorted by concurrency level
    rows: List[CsvRow] = []
    for concurrency_level in sorted(concurrency_map.keys()):
        values = concurrency_map[concurrency_level]
        missing_metrics = [
            metric_key for _, metric_key in METRIC_FIELD_MAP if metric_key not in values
        ]
        if missing_metrics:
            raise ValueError(
                f"Concurrency {concurrency_level} missing metrics: {', '.join(missing_metrics)}"
            )

        row = [
            endpoint,
            str(concurrency_level),
        ]
        for _, metric_key in METRIC_FIELD_MAP:
            row.append(format_number(values[metric_key]))
        rows.append(row)

    return rows


def write_csv(output_path: Optional[Path], rows: List[CsvRow]) -> None:
    """
    Write CSV rows to file or stdout.
    
    Args:
        output_path: File path to write CSV. If None, writes to stdout.
        rows: List of CSV rows to write (excluding header).
    """
    if output_path is not None:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with output_path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(CSV_HEADER)
            writer.writerows(rows)
    else:
        # Write to stdout (status messages go to stderr to avoid polluting CSV output)
        writer = csv.writer(sys.stdout)
        writer.writerow(CSV_HEADER)
        writer.writerows(rows)


def main() -> None:
    args = parse_args()
    
    # Resolve paths
    # NOTE: --results-dir should be the TOP-LEVEL directory (e.g. 'concurrency-tests-lepton-vllm-2x-a100-sxm4/')
    #       NOT the 'concurrency-test-results/' subdirectory
    results_dir = Path(args.results_dir).expanduser().resolve()
    metrics_override = Path(args.metrics_file).expanduser().resolve() if args.metrics_file else None
    metrics_path = resolve_metrics_path(results_dir, metrics_override)
    
    # If --output is provided, write to file; otherwise write to stdout
    output_path = (
        Path(args.output).expanduser().resolve()
        if args.output
        else None
    )

    metrics_data = load_metrics_data(metrics_path)
    rows = build_rows(args.endpoint, metrics_data)
    write_csv(output_path, rows)

    # Print status message to stderr so it doesn't interfere with stdout CSV
    if output_path is not None:
        print(f"✅ Generated {len(rows)} rows at {output_path}", file=sys.stderr)
    else:
        print(f"✅ Generated {len(rows)} rows to stdout", file=sys.stderr)


if __name__ == "__main__":
    main()

