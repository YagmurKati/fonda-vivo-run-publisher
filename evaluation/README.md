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
| `queries/carbon-sources.rq` | SPARQL query: carbon-intensity source, time resolution and emissions basis of each run |
| `data/runs.csv` | output of `runs.rq` |
| `data/step-sums.csv` | output of `step-sums.rq` |
| `data/carbon-sources.csv` | output of `carbon-sources.rq` |
| `evaluate.py` | selects the 100 runs and computes completeness, step-to-run sums and coefficients of variation |
| `carbon-15min/` | script and queries of the 15-minute carbon recalculation of 2026-11-07 (see Notes) |

## Repeat the checks

```
python3 evaluate.py
```

No packages besides Python 3 are needed. To repeat the checks on the live data, run the queries on the public
records (https://vivo-fonda.hu-berlin.de/) and replace the CSV files.

## Notes

- Values are as stored in the records: energy in kWh, carbon in kg CO2e, CPU time and duration in seconds.
- On HPC@HU, step CPU time adds up to 54-57 % of the run CPU time: the run value covers the whole Slurm job,
  the step values only the tasks.
- The node meter of Fonda cannot split energy by step. Only 64 of the 600 Fonda step records have energy and
  carbon, from the few pods that Kepler measured; they do not add up to the run. `step-sums.rq` counts the steps
  that have a value (`stepsWithEnergy`, `stepsWithCarbon`), and `evaluate.py` compares a sum with the run value
  only when every step has one.
- Carbon: on 2026-11-07 the carbon of the 100 runs was recalculated with 15-minute Electricity Maps factors
  (zone DE, lifecycle, flow-traced) instead of hourly ones, with the same method: the run's energy is split across
  the quarter-hours it covers by its node power readings. Most values changed by -5 % to +3 % (one run +9 %),
  mainly because Electricity Maps had revised its past data since the hourly values were fetched. HPC@HU step
  carbon was scaled with its run. Each record states the old and the new value.
- One HPC@HU run (`hpc-at-hu-slurm-1597982`, 2026-10-02) first used a CO2Map.de factor with direct CO2 emissions.
  On 2026-11-06 it was recalculated with the Electricity Maps factor (lifecycle), as all other runs.

Licensed under CC BY 4.0 (data) and MIT (script).
