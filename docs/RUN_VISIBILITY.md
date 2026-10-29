# Who can see your run

Runs are public. FONDA aims at reproducible research, so please share at least
one run of each workflow publicly. Other runs you can hide, for example results
that are not published yet, or a series of runs you only want to compare.

## Change it on the run page

After your run is published, you can change who sees it at any time:

1. Log in to [FONDA VIVO](https://vivo-fonda.hu-berlin.de).
2. Open the page of your run.
3. Under **who can see this run**, choose:

| Choice in VIVO | Who sees the run |
| --- | --- |
| Everyone (public) | everyone (this is the default) |
| Logged-in users only | people logged in to VIVO |
| Only me (the person who ran it) | only you |

Only the person who ran the run (its "run by") can change this. The choice also
applies to the pages of the run's workflow stages.

## Or choose it when you publish

Add `--visibility public`, `logged-in` or `private` to the publish command:

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
the end (`Visibility: ...`). If you publish a run again without a choice, it
keeps the one you made on its page.

`private` means: only the run's "run by" person, so set `RUN_OPERATOR_URI` to
your VIVO person URI.

## Good to know

A hidden run's title can still appear in VIVO's search results and run lists.
Its page, its values and its RDF open only for the people you chose.
