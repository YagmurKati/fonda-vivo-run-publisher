# 15-minute carbon for the 100 rangeland runs of the paper

Replaces the hourly carbon values of the 100 runs (50 Fonda, 50 HPC@HU) with values from 15-minute
Electricity Maps data (zone DE, lifecycle, flow-traced). The method is the same as before, with quarter-hours
instead of hours. Step carbon of HPC@HU runs is scaled by the same factor, so steps still add up to the run.
Energy, CPU time and all other values stay as they are.

## Steps

1. **Export (backup).** VIVO > Site Admin > SPARQL Query. Paste `1_export.rq`, format **N-Triples**, run,
   save the result as `export.nt` in this folder. Keep it.
2. **Calculate.** In a terminal, in this folder:

       export ELECTRICITY_MAPS_API_TOKEN='your token'
       python3 carbon_15min.py export.nt

   It prints the number of triples and the range of changes, and writes `carbon15_REMOVE.nt`,
   `carbon15_ADD.nt` and `carbon15_report.csv` (old and new value of every run). Send the printed lines and
   the report before uploading.
3. **Upload.** Site Admin > Add/Remove RDF data, format N-Triples:
   first `carbon15_REMOVE.nt` with "remove mixed RDF", then `carbon15_ADD.nt` with "add mixed RDF".
4. **Check.** Run `2_check.rq` (expected: "15 minutes" 100, "hourly" 24) and `3_check-duplicates.rq`
   (expected: no rows).

## Undo

Upload `carbon15_ADD.nt` with "remove mixed RDF", then `carbon15_REMOVE.nt` with "add mixed RDF".
