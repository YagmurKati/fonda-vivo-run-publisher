#!/usr/bin/env python3
"""Recompute the numbers of Section 5 ("Evaluation") of the paper
"An Ontology Extension for Reproducible Workflow Energy and Carbon Accounting" (Mid4CC '26)
from the two CSV exports in data/ (made with the queries in queries/).

Selection: runs of the nf-core/rangeland test profile that had one node to themselves:
  Fonda (Kubernetes):  rm:nodeUse starts with "exclusive" and one execution host;
  HPC@HU (Slurm):      energy source is the IPMI power of the whole node and one execution host.
Checks:
  completeness: the run fields below are present;
  consistency:  sums of the step records against the run values (energy, carbon, CPU time, tasks);
  variation:    coefficient of variation (sample SD / mean) per cluster.

usage: python3 evaluate.py [data/runs.csv data/step-sums.csv]
"""
import csv
import statistics as st
import sys
from collections import Counter
from pathlib import Path

here = Path(__file__).resolve().parent
runs_csv = Path(sys.argv[1]) if len(sys.argv) > 2 else here / "data" / "runs.csv"
steps_csv = Path(sys.argv[2]) if len(sys.argv) > 2 else here / "data" / "step-sums.csv"

def num(x):
    try:
        return float(x.replace("E", "e"))
    except (AttributeError, ValueError):
        return None

runs = list(csv.DictReader(open(runs_csv, newline="")))
steps = {r["run"]: r for r in csv.DictReader(open(steps_csv, newline="")) if r.get("run")}
cluster = lambda r: r["cluster"].rsplit("/", 1)[-1]

groups = {
    "Fonda (Kubernetes)": [r for r in runs if cluster(r) == "fonda-cluster"
                           and r["nodeUse"].startswith("exclusive") and r["hosts"] == "1"],
    "HPC@HU (Slurm)": [r for r in runs if cluster(r) == "hpc-hu-cluster"
                       and r["source"].startswith("IPMI power") and r["hosts"] == "1"],
}
FIELDS = ["energyKWh", "carbonKg", "cpuS", "durS", "tasks", "source", "granularity", "fallback"]
METRICS = [("energyKWh", "energy"), ("carbonKg", "carbon"), ("cpuS", "CPU time"), ("durS", "duration")]
PAIRS = [("energyKWh", "stepEnergyKWh"), ("carbonKg", "stepCarbonKg"), ("cpuS", "stepCpuS"), ("tasks", "stepTasks")]
WITH = {"stepEnergyKWh": "stepsWithEnergy", "stepCarbonKg": "stepsWithCarbon"}

total_runs = total_steps = 0
for name, R in groups.items():
    total_runs += len(R)
    print(f"\n== {name}: {len(R)} runs, {min(r['start'] for r in R)} to {max(r['start'] for r in R)}")
    missing = sum(1 for r in R for f in FIELDS if not r[f])
    print(f"   completeness: {missing} missing values in {', '.join(FIELDS)}")
    print(f"   carbon granularity: {dict(Counter(r['granularity'] for r in R))}, "
          f"fallback estimates: {dict(Counter(r['fallback'] for r in R))}")
    n_steps = Counter(steps[r['run']]['steps'] for r in R if r['run'] in steps)
    total_steps += sum(int(k) * v for k, v in n_steps.items())
    print(f"   step records per run: {dict(n_steps)}")
    for rk, sk in PAIRS:
        # A sum is compared with the run value only if every step of the run has a value.
        count = WITH.get(sk)
        full = [r for r in R if r['run'] in steps and (count is None or steps[r['run']][count] == steps[r['run']]['steps'])]
        some = sum(int(steps[r['run']][count]) for r in R if count and r['run'] in steps)
        ratios = [num(steps[r['run']][sk]) / num(r[rk]) for r in full if num(r[rk])]
        if ratios:
            print(f"   step sum / run value, {rk:9s}: min {min(ratios):.4f}  max {max(ratios):.4f}  ({len(ratios)} runs)")
        else:
            print(f"   step sum / run value, {rk:9s}: no run with a value on every step ({some} step values in total)")
    for key, label in METRICS:
        v = [num(r[key]) for r in R if num(r[key]) is not None]
        print(f"   {label:9s}: n={len(v)}  mean={st.mean(v):.6g}  SD={st.stdev(v):.3g}  CV={100 * st.stdev(v) / st.mean(v):.1f}%")
print(f"\nTotal: {total_runs} runs, {total_steps} step records")
