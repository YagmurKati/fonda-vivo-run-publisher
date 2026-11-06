# Evaluation data

Data and script behind Section 5 ("Evaluation") of the paper
*An Ontology Extension for Reproducible Workflow Energy and Carbon Accounting* (Mid4CC '26).

The evaluation checks the published records of 100 runs of the nf-core/rangeland test profile (version 1.0.0):
50 on the Kubernetes cluster Fonda and 50 on the Slurm cluster HPC@HU, each run with one node to itself.
The same runs are used in the demonstration paper *Demo Abstract: FAIR Workflow Energy and Carbon Records*
(Middleware '26), which compares the two clusters.

| File | Content |
|---|---|
| `queries/runs.rq` | SPARQL query: one line per run of the workflow |
| `queries/step-sums.rq` | SPARQL query: sums of the step records of each run |
| `queries/carbon-sources.rq` | SPARQL query: carbon-intensity source and emissions basis of each run |
| `data/runs.csv` | output of `runs.rq` |
| `data/step-sums.csv` | output of `step-sums.rq` |
| `evaluate.py` | selects the 100 runs and computes completeness, step-to-run sums and coefficients of variation |

## Repeat the checks

```
python3 evaluate.py
```

No packages besides Python 3 are needed. To repeat the checks on the live data, run the queries on the public
records (https://vivo-fonda.hu-berlin.de/) and replace the two CSV files.

## Notes

- Values are as stored in the records: energy in kWh, carbon in kg CO2e, CPU time and duration in seconds.
- On HPC@HU, step CPU time adds up to 54-57 % of the run CPU time: the run value covers the whole Slurm job,
  the step values only the tasks. Fonda step records have no energy: the node meter cannot split energy by step.
- One HPC@HU run (`hpc-at-hu-slurm-1597982`, 2026-10-02) first used a CO2Map.de factor with direct CO2 emissions.
  On 2026-11-06 its factor was replaced by the Electricity Maps value for the same hour (397 g CO2e/kWh, lifecycle),
  as for all other runs; its record states this.

Licensed under CC BY 4.0 (data) and MIT (script).
