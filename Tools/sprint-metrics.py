#!/usr/bin/env python3
"""Extracts metric list from Entry Gate report for Close Gate verification.

Usage:
    python3 sprint-metrics.py S1              # list metrics
    python3 sprint-metrics.py S1 --scaffold   # output scaffold table for Close Gate
"""

import re
import sys

from sprint_lib.utils import find_project_root
from sprint_lib.gate_parser import find_gate_file, extract_metrics


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python3 sprint-metrics.py <sprint> [--scaffold]", file=sys.stderr)
        sys.exit(1)

    sprint_arg = sys.argv[1]
    scaffold = "--scaffold" in sys.argv

    # Extract sprint number from argument (e.g. "S1" -> 1, "1" -> 1)
    m = re.match(r"S?(\d+)", sprint_arg)
    if not m:
        print(f"Error: Invalid sprint identifier '{sprint_arg}'", file=sys.stderr)
        sys.exit(1)
    sprint_n = int(m.group(1))

    try:
        root = find_project_root()
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    gate_file = find_gate_file(root, sprint_n, "entry")
    if gate_file is None:
        print(
            f"Error: No Entry Gate report found for S{sprint_n}",
            file=sys.stderr,
        )
        sys.exit(1)

    metrics = extract_metrics(gate_file)
    if not metrics:
        print(f"No metrics found in {gate_file.name}")
        sys.exit(0)

    if scaffold:
        print("| Item | Metric | Status | Evidence |")
        print("|------|--------|--------|----------|")
        for m in metrics:
            print(f"| {m.item_id} | {m.metric_text} | — | — |")
    else:
        print(f"Metrics from {gate_file.name}:")
        print()
        for m in metrics:
            print(f"  {m.item_id}: {m.metric_text}")


if __name__ == "__main__":
    main()
