#!/usr/bin/env python3
"""
summarize.py — reads all VT-XX_results.csv files and prints a summary table.
Run from tests/verification/: python3 summarize.py
"""

import csv
import os
import statistics
from pathlib import Path

RESULTS_DIR = Path(__file__).parent / "results"
SPEC = {
    "VT-01": 1000,
    "VT-02": None,
    "VT-03": 5000,
    "VT-04": 500,
    "VT-05": 2000,
    "VT-06": 1000,
    "VT-07": 500,
    "VT-09": 1000,
    "VT-10": 500,
    "VT-12": 2000,
    "VT-13": 2000,
}

def find_time_column(headers):
    for candidate in ["response_time_ms", "render_time_ms", "inject_to_seen_ms",
                       "inject_to_receipt_ms", "post_ms", "response_ms",
                       "latency_ms", "query_ms", "commit_latency_ms",
                       "detection_latency_ms", "inject_to_enter_ms"]:
        if candidate in headers:
            return candidate
    return None

def summarize(vt_id, csv_path):
    rows = []
    with open(csv_path) as f:
        reader = csv.DictReader(f)
        headers = reader.fieldnames or []
        for row in reader:
            rows.append(row)

    if not rows:
        return {"vt": vt_id, "n": 0, "pass": 0, "fail": 0, "rate": "N/A",
                "mean": "N/A", "p95": "N/A", "spec": SPEC.get(vt_id, "?"), "status": "NO DATA"}

    pf_col = "pass_fail" if "pass_fail" in headers else None
    time_col = find_time_column(headers)

    passes = sum(1 for r in rows if pf_col and r.get(pf_col, "").upper() == "PASS")
    fails  = sum(1 for r in rows if pf_col and r.get(pf_col, "").upper() == "FAIL")
    n = len(rows)
    rate = f"{passes/n*100:.0f}%" if n else "N/A"

    times = []
    if time_col:
        for r in rows:
            try:
                v = float(r[time_col])
                if v > 0:
                    times.append(v)
            except (ValueError, TypeError):
                pass

    mean_v = f"{statistics.mean(times):.0f}ms" if times else "N/A"
    p95_v = "N/A"
    if times:
        s = sorted(times)
        p95_v = f"{s[min(int(len(s)*0.95), len(s)-1)]:.0f}ms"

    spec_v = SPEC.get(vt_id)
    spec_str = f"{spec_v}ms" if spec_v else "—"

    if passes == n:
        status = "PASS"
    elif fails == n:
        status = "FAIL"
    elif passes > fails:
        status = "PARTIAL"
    else:
        status = "FAIL"

    return {"vt": vt_id, "n": n, "pass": passes, "fail": fails,
            "rate": rate, "mean": mean_v, "p95": p95_v,
            "spec": spec_str, "status": status}

def main():
    if not RESULTS_DIR.exists():
        print(f"No results directory found at {RESULTS_DIR}")
        print("Run the test scripts first.")
        return

    summaries = []
    for vt_id in sorted(SPEC.keys()):
        pattern = f"{vt_id}_results.csv"
        matches = list(RESULTS_DIR.glob(pattern))
        if not matches:
            summaries.append({"vt": vt_id, "n": 0, "pass": 0, "fail": 0,
                               "rate": "—", "mean": "—", "p95": "—",
                               "spec": f"{SPEC[vt_id]}ms" if SPEC[vt_id] else "—",
                               "status": "NOT RUN"})
        else:
            summaries.append(summarize(vt_id, matches[0]))

    # Print table
    col_w = [6, 4, 5, 5, 7, 8, 8, 8, 10]
    headers = ["Test", "n", "Pass", "Fail", "Rate", "Mean", "p95", "Spec", "Status"]
    sep = "+" + "+".join("-" * (w + 2) for w in col_w) + "+"
    fmt = "| " + " | ".join(f"{{:<{w}}}" for w in col_w) + " |"

    print()
    print("PhytoPi Verification Test Summary")
    print(sep)
    print(fmt.format(*headers))
    print(sep)
    for s in summaries:
        print(fmt.format(
            s["vt"], s["n"], s["pass"], s["fail"],
            s["rate"], s["mean"], s["p95"], s["spec"], s["status"]
        ))
    print(sep)
    print()

    total_pass = sum(1 for s in summaries if s["status"] == "PASS")
    total_run  = sum(1 for s in summaries if s["status"] != "NOT RUN")
    print(f"Overall: {total_pass}/{total_run} tests PASSED")
    print()

    # One-liner block for copy-paste
    print("--- Copy-paste block for appendix ---")
    for s in summaries:
        print(f"{s['vt']}: {s['status']} | n={s['n']} pass={s['pass']} p95={s['p95']}")

if __name__ == "__main__":
    main()
