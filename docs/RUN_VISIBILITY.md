# Who can see your run

Runs are public. FONDA aims at reproducible research, so please share at least
one run of each workflow publicly. Other runs you can hide, for example results
that are not published yet, or a series of runs you only want to compare.

| Choice | Who sees the run |
| --- | --- |
| `public` (default) | everyone |
| `logged-in` | people logged in to VIVO |
| `private` | only you |

The choice also applies to the pages of the run's workflow stages.

## When you publish

Add `--visibility` to the publish command:

```bash
# FONDA Kubernetes cluster
./scripts/publish-run.sh my-run-01 --visibility private

# HPC@HU (Slurm)
examples/hpc-at-hu-slurm/publish-slurm-job.sh JOB_ID --visibility private

# Publishing step by step (step 4 of the README)
./scripts/publish-local.sh "$OUTPUT_TTL" --visibility private
```

For all your runs, set it once in your settings file (`config/publisher.env`
or `~/.fonda-vivo/slurm.env`):

```bash
RUN_VISIBILITY="logged-in"
```

`--visibility` wins over `RUN_VISIBILITY`. The publisher prints the choice at
the end (`Visibility: ...`).

`private` means: only the run's "run by" person, so set `RUN_OPERATOR_URI` to
your VIVO person URI.

## Later, in VIVO

Log in, open the run and edit **who can see this run**. Only you, as the run's
"run by" person, can change it. Publishing the run again without
`--visibility` keeps this choice.

## Good to know

A hidden run's title can still appear in VIVO's search results and run lists.
Its page, its values and its RDF open only for the people you chose.
