#!/usr/bin/env python3
"""Whole-node energy, idle power and grid carbon (15-minute, else hourly) for a FONDA Kubernetes run on ONE node.

Add-on to collect_nextflow_run_metadata.py, which stays unchanged. It starts from a run that
scripts/publish-run.sh has already published (the run's Turtle file in the PVC outbox) and adds
what the HPC@HU runs have, so the run page shows the same charts (idle vs. work, power over
time, "was the timing green?"):

  rm:nodeIdlePowerW            mean power of the node in a quiet window before and after the run
  rm:energyAboveIdleKWh        node energy during the run minus idle power x duration
  rm:idlePowerMethod           how the idle power was found, in words
  rm:nodePowerAvgW, rm:nodePowerMaxW
  rm:nodePowerReadings         power of the node during the run (seconds since start, watts)
  rm:gridCarbonIntensityHours  hourly German grid intensity around the run (Electricity Maps)

Only for a run on a single node that was published as exclusive (rm:nodeUse "exclusive ...").
Such a run is accounted like an exclusive HPC@HU job: its energy becomes the whole node's
measured energy during the run, read from Kepler's kepler_node_platform_joules_total (the
node's ACPI power meter), instead of the sum of its pods' Kepler shares. When Electricity Maps
covers the run's time, its carbon becomes time-matched: to its quarter-hours where the account has
15-minute data, else to its hours.

Writes, for Site Admin > Add/Remove RDF data (format Turtle):
  RUN-node-power_REMOVE.ttl   the run's current values of every property that is replaced
  RUN-node-power_ADD.ttl      the new values
Upload REMOVE first ("remove mixed RDF"), then ADD ("add mixed RDF"). To undo: upload ADD with
"remove mixed RDF", then REMOVE with "add mixed RDF".
"""
import argparse
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rapl_carbon import api_token, covered_intervals, electricity_points, stamp  # noqa: E402

UTC = timezone.utc
BERLIN = ZoneInfo("Europe/Berlin")
ENERGY_METRIC = "kepler_node_platform_joules_total"
IDLE_WINDOW = 600          # seconds of each quiet window
IDLE_GAP = 60              # seconds between a quiet window and the run
BUSY_CPUS_WARN = 2.0       # more busy CPUs than this in a quiet window gives a warning
# Checked once with the processor's own counters (MSR) on an idle node, 2026-11-01; all nodes are of one type.
SLEEP_NOTE = ("The node saves energy when nothing runs: its idle processor cores and the processor package "
              "sleep (hardware counters on hu-worker-c39, 2026-11-01: cores in deep sleep 93% and the package "
              "44% of the time). All nodes of the cluster have the same processor type.")


def idle_power_method(node, idle_w, window_texts):
    """rm:idlePowerMethod: window_texts like '13:00-13:10 Berlin time 148.9 W (0.12 CPUs busy on average)',
    the window before the run first."""
    two = len(window_texts) > 1
    return (f"Idle power of node {node}: {idle_w:.1f} W, the mean power of the node (ACPI power meter, read by "
            f"Kepler) in {'two quiet windows' if two else 'one quiet window'} of {IDLE_WINDOW // 60} minutes, "
            f"{IDLE_GAP} s before{' and after' if two else ''} the run: " + "; ".join(window_texts) + ". "
            + SLEEP_NOTE + " Energy above idle is the energy above this value, so it includes the energy needed "
            "to keep the node awake for the job.")
MAX_POINTS = 600
HOURS_AROUND = 24
EM_HISTORY = "https://api.electricitymaps.com/v4/carbon-intensity/history"
EM_PAST_RANGE = "https://api.electricitymaps.com/v4/carbon-intensity/past-range"
WHOLE_NODE = "100% of the node (whole node, measured)"


class Stop(Exception):
    pass


# ---------------------------------------------------------------- Turtle of the published run
def read_ttl(text):
    """{subject: [(predicate, object text, line)]} for the publisher's one-triple-per-line Turtle."""
    resources, subject = {}, None
    for line in text.splitlines():
        if not line.strip() or line.startswith("@prefix"):
            continue
        if not line.startswith(" "):
            subject = line.strip()
            resources.setdefault(subject, [])
            continue
        body = line.strip()
        if body.endswith((" ;", " .")):
            body = body[:-2]
        predicate, _, obj = body.partition(" ")
        resources.setdefault(subject, []).append((predicate, obj.strip(), line))
    return resources


def literal_text(obj):
    """Lexical value of a Turtle literal written by ttl_literal()."""
    if not obj.startswith('"'):
        return obj
    out, i = [], 1
    while i < len(obj):
        c = obj[i]
        if c == "\\" and i + 1 < len(obj):
            out.append({"n": "\n", "r": "\r"}.get(obj[i + 1], obj[i + 1]))
            i += 2
            continue
        if c == '"':
            break
        out.append(c)
        i += 1
    return "".join(out)


def ttl_escape(value):
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\r", "\\r").replace("\n", "\\n")


def lit(value, datatype=None):
    if isinstance(value, bool):
        return f"\"{'true' if value else 'false'}\"^^xsd:boolean"
    if isinstance(value, int):
        return f'"{value}"^^{datatype or "xsd:integer"}'
    if isinstance(value, float):
        return f'"{repr(value)}"^^{datatype or "xsd:double"}'
    text = f'"{ttl_escape(str(value))}"'
    return f"{text}^^{datatype}" if datatype else text


def run_facts(resources):
    runs = [s for s, triples in resources.items() if ("rdf:type", "rm:RunMetadata") in [(p, o) for p, o, _ in triples]]
    if len(runs) != 1:
        raise Stop(f"expected one rm:RunMetadata in the Turtle file, found {len(runs)}")
    subject = runs[0]
    values = {}
    for predicate, obj, _ in resources[subject]:
        values.setdefault(predicate, []).append(literal_text(obj))
    return subject, values


def local_to_epoch(text):
    """The collector writes run times as Berlin local time without zone."""
    parsed = datetime.fromisoformat(text)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=BERLIN)
    return parsed.timestamp()


# ---------------------------------------------------------------- Prometheus
def prom_get(prom_url, path, params):
    url = prom_url.rstrip("/") + path + "?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=60) as response:
        payload = json.load(response)
    if payload.get("status") != "success":
        raise Stop(f"Prometheus error for {params.get('query')}: {payload.get('error')}")
    return payload["data"]["result"]


def instant(prom_url, query, at):
    result = prom_get(prom_url, "/api/v1/query", {"query": query, "time": f"{at:.3f}"})
    values = [float(r["value"][1]) for r in result if math.isfinite(float(r["value"][1]))]
    return sum(values) if values else None


def series(prom_url, query, start, end, step):
    result = prom_get(prom_url, "/api/v1/query_range",
                      {"query": query, "start": f"{start:.3f}", "end": f"{end:.3f}", "step": f"{step}s"})
    points = {}
    for item in result:
        for t, v in item.get("values", []):
            v = float(v)
            if math.isfinite(v):
                points[float(t)] = points.get(float(t), 0.0) + v
    return sorted(points.items())


def sel(node):
    return f'{ENERGY_METRIC}{{instance="{node}"}}'


def scrape_interval(prom_url, node, at):
    counts = prom_get(prom_url, "/api/v1/query",
                      {"query": f"count_over_time({sel(node)}[600s])", "time": f"{at:.3f}"})
    best = max((float(r["value"][1]) for r in counts), default=0)
    if best < 2:
        raise Stop(f"Prometheus has no {ENERGY_METRIC} for node {node} at that time")
    return 600.0 / best


def node_energy(prom_url, node, start, end):
    seconds = max(1, int(round(end - start)))
    value = instant(prom_url, f"sum(increase({sel(node)}[{seconds}s]))", end)
    if value is None or value <= 0:
        raise Stop(f"no {ENERGY_METRIC} increase for node {node} during the run")
    return value


def quiet_window(prom_url, node, window_end):
    watts = instant(prom_url, f"sum(increase({sel(node)}[{IDLE_WINDOW}s]))", window_end)
    busy = instant(prom_url, f'sum(rate(container_cpu_usage_seconds_total{{id="/",node="{node}"}}[{IDLE_WINDOW}s]))',
                   window_end)
    return dict(start=window_end - IDLE_WINDOW, end=window_end,
                watts=None if watts is None else watts / IDLE_WINDOW, busy_cpus=busy)


def power_readings(prom_url, node, start, end, interval):
    """[(seconds since the run start, watts)] from the run start to the run end. Each value is the
    average power over `window` seconds centred on its time (no delay), every `step` seconds, plus
    one value exactly at the run's end."""
    step = max(5, int(round(interval)))
    window = max(30, int(math.ceil(2 * interval)) + 1)
    half = window / 2
    query = f"sum(rate({sel(node)}[{window}s]))"
    points = [(t - half - start, w) for t, w in series(prom_url, query, start + half, end + half, step)]
    points = [(o, w) for o, w in points if -1 <= o <= end - start + 1]
    if not points or end - start - points[-1][0] > 1:
        last = instant(prom_url, query, end + half)
        if last is not None:
            points.append((end - start, last))
    if len(points) > MAX_POINTS:
        width = (end - start) / MAX_POINTS
        bins = {}
        for offset, w in points:
            bins.setdefault(min(MAX_POINTS - 1, int(offset // width)), []).append(w)
        points = [((i + 0.5) * width, sum(v) / len(v)) for i, v in sorted(bins.items())]
    return points, step, window


# ---------------------------------------------------------------- grid carbon
def fetch_history(token, granularity="hourly", start=None, end=None):
    """Last 24 hours (history), or [start, end) rounded out to whole intervals (past-range)."""
    params = dict(zone="DE", temporalGranularity=granularity, emissionFactorType="lifecycle", flowTraced="true")
    endpoint = EM_HISTORY
    if start is not None and end is not None:
        seconds = 900 if granularity == "15_minutes" else 3600
        endpoint = EM_PAST_RANGE
        params["start"] = datetime.fromtimestamp(math.floor(start / seconds) * seconds, UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
        params["end"] = datetime.fromtimestamp(math.ceil(end / seconds) * seconds, UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
    url = endpoint + "?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={"auth-token": token})
    with urllib.request.urlopen(request, timeout=30) as response:
        return url, electricity_points(json.load(response), granularity)


def hour_text(epoch):
    return datetime.fromtimestamp(epoch, UTC).strftime("%Y-%m-%dT%H:%MZ")


def energy_shares(intervals, readings, start):
    """Share of the run's energy in each piece, from the power readings; time share if too few."""
    def energy_in(a, b):
        pts = [(start + o, w) for o, w in readings]
        if len(pts) < 2:
            return None
        total = 0.0
        for (t0, w0), (t1, w1) in zip(pts, pts[1:]):
            lo, hi = max(a, t0), min(b, t1)
            if hi <= lo:
                continue
            f0 = w0 + (w1 - w0) * (lo - t0) / (t1 - t0)
            f1 = w0 + (w1 - w0) * (hi - t0) / (t1 - t0)
            total += (f0 + f1) / 2 * (hi - lo)
        return total
    parts = [energy_in(p["start"], p["end"]) for p in intervals]
    if any(p is None for p in parts) or sum(parts) <= 0:
        parts = [p["end"] - p["start"] for p in intervals]
    total = sum(parts)
    return [p / total for p in parts]


# ---------------------------------------------------------------- main
def build(args):
    resources = read_ttl(Path(args.ttl).read_text())
    run, values = run_facts(resources)
    hosts = values.get("rm:executionHost", [])
    if len(set(hosts)) != 1:
        raise Stop(f"the run used {len(set(hosts))} nodes ({', '.join(sorted(set(hosts)))}); this add-on is for one node")
    node = hosts[0]
    use = (values.get("rm:nodeUse") or [""])[0]
    if not use.startswith("exclusive") and not args.allow_shared:
        raise Stop(f"the run is not published as exclusive (node use: {use or 'not recorded'})")
    start = local_to_epoch(values["prov:startedAtTime"][0])
    end = local_to_epoch(values["prov:endedAtTime"][0])
    duration = end - start
    if duration <= 0:
        raise Stop("run end is not after its start")
    old_energy = float(values["rm:energyKWh"][0]) if values.get("rm:energyKWh") else None
    now = args.now or time.time()

    interval = scrape_interval(args.prom_url, node, end)
    energy_j = node_energy(args.prom_url, node, start, end)
    energy_kwh = energy_j / 3_600_000
    windows = [quiet_window(args.prom_url, node, start - IDLE_GAP)]
    after_end = end + IDLE_GAP + IDLE_WINDOW
    if now >= after_end + 30:
        windows.append(quiet_window(args.prom_url, node, after_end))
    windows = [w for w in windows if w["watts"] is not None]
    if not windows:
        raise Stop("no node power before the run; cannot determine the idle power")
    idle_w = sum(w["watts"] for w in windows) / len(windows)
    above_kwh = (energy_j - idle_w * duration) / 3_600_000
    readings, step, rate_window = power_readings(args.prom_url, node, start, end, interval)
    avg_w = energy_j / duration
    max_w = max((w for _, w in readings), default=None)
    warnings = []
    for w in windows:
        if w["busy_cpus"] is not None and w["busy_cpus"] > BUSY_CPUS_WARN:
            warnings.append(f"the node had {w['busy_cpus']:.1f} busy CPUs in the quiet window "
                            f"{hour_text(w['start'])[11:16]}-{hour_text(w['end'])[11:16]} UTC; the idle power may be too high")
    if len(windows) == 1:
        warnings.append("only the window before the run was used (the window after it has not passed yet, "
                        "or Prometheus has no data for it)")

    def window_text(w):
        busy = "" if w["busy_cpus"] is None else f", {w['busy_cpus']:.2f} CPUs busy on average"
        return (f"{datetime.fromtimestamp(w['start'], BERLIN):%H:%M}-{datetime.fromtimestamp(w['end'], BERLIN):%H:%M} "
                f"Berlin time: {w['watts']:.1f} W{busy}")

    new = {}
    removed = []
    when = datetime.fromtimestamp(start, BERLIN)
    conditions = (f"Idle power: {idle_w:.0f} W, the mean power of node {node} (ACPI power meter, read by Kepler as "
                  f"{ENERGY_METRIC}) in {len(windows)} quiet window{'s' if len(windows) > 1 else ''} of "
                  f"{IDLE_WINDOW // 60} minutes, {IDLE_GAP} s before{' and after' if len(windows) > 1 else ''} the run "
                  f"on {when:%Y-%m-%d}: " + "; ".join(window_text(w) for w in windows) + ". "
                  f"Energy above idle = (node energy {energy_j:.0f} J - {idle_w:.0f} W x {duration:.0f} s) = "
                  f"{energy_j - idle_w * duration:.0f} J = {above_kwh:.6f} kWh."
                  + ("" if not warnings else " Note: " + "; ".join(warnings) + "."))
    new["rm:nodeIdlePowerW"] = [lit(round(idle_w, 1))]
    new["rm:idlePowerMethod"] = [lit(idle_power_method(node, round(idle_w, 1), [
        f"{datetime.fromtimestamp(w['start'], BERLIN):%H:%M}-{datetime.fromtimestamp(w['end'], BERLIN):%H:%M} "
        f"Berlin time {w['watts']:.1f} W"
        + ("" if w["busy_cpus"] is None else f" ({w['busy_cpus']:.2f} CPUs busy on average)") for w in windows]))]
    new["rm:energyAboveIdleKWh"] = [lit(above_kwh)]
    new["rm:nodePowerAvgW"] = [lit(round(avg_w, 1))]
    if max_w is not None:
        new["rm:nodePowerMaxW"] = [lit(round(max_w, 1))]
    new["rm:nodeConditionsMethod"] = [lit(conditions)]
    if len(readings) >= 3:
        text = "; ".join(f"{o:.1f} {w:.0f}" for o, w in readings)
        new["rm:nodePowerReadings"] = [lit(text)]
        new["rm:nodePowerReadingsMethod"] = [lit(
            f"Power of the whole node {node} from its ACPI power meter, read by Kepler ({ENERGY_METRIC}) and "
            f"stored in Prometheus about every {interval:.0f} s; each value is the average power over the "
            f"{rate_window} s centred on its time, every {step} s and at the run's end: {len(readings)} readings. "
            f"Each entry is the time since the run "
            f"started ({datetime.fromtimestamp(start, UTC).isoformat()}) in seconds and the node's power in watts.")]
    new["rm:energyKWh"] = [lit(energy_kwh)]
    new["rm:energyMeasurementCoverage"] = [lit(WHOLE_NODE)]
    new["rm:energyMetricSource"] = [lit(f"{ENERGY_METRIC} (ACPI power meter of the node, read by Kepler)")]
    new["rm:energyCalculationUsesFallbackEstimate"] = [lit(False)]
    new["rm:energyCalculationMethod"] = [lit(
        f"Whole-node energy: the run had node {node} to itself ({use}), so all of the node's energy during the run "
        f"is the run's energy, as for an exclusive HPC@HU job. Node energy = increase of {ENERGY_METRIC} "
        f"(the node's ACPI power meter, read by Kepler) from {datetime.fromtimestamp(start, UTC).isoformat()} to "
        f"{datetime.fromtimestamp(end, UTC).isoformat()} = {energy_j:.0f} J = {energy_kwh:.6f} kWh, including the "
        f"node's idle power; cooling and network are excluded."
        + (f" It replaces the sum of the run's pods' Kepler shares ({old_energy:.6f} kWh), which misses pods "
           "that finished between Kepler readings." if old_energy is not None else ""))]

    # carbon: time-matched hours from Electricity Maps when they cover the run
    carbon_note = None
    try:
        token = args.token or api_token(args.namespace)
        if not token:
            raise Stop("no Electricity Maps token (ELECTRICITY_MAPS_API_TOKEN or the cluster secret)")
        # hourly history: the hours around the run for the run page (rm:gridCarbonIntensityHours)
        hour_error = None
        try:
            hour_url, points = fetch_history(token)
        except (ValueError, KeyError, urllib.error.URLError, OSError) as exc:
            hour_url, points, hour_error = "", [], exc
        # carbon: 15-minute values of the run's own time where the account has them, else hourly
        try:
            source_url, quarter_points = fetch_history(token, "15_minutes", start, end)
            intervals = covered_intervals(quarter_points, start, end)
            granularity, unit, unit_s = "15 minutes", "quarter-hour", "15-minute"
        except (ValueError, KeyError, urllib.error.URLError, OSError):
            if hour_error is not None:
                raise hour_error
            source_url, intervals = hour_url, covered_intervals(points, start, end)
            granularity, unit, unit_s = "hourly", "hour", "hourly"
        shares = energy_shares(intervals, readings, start)
        g = sum(s * p["g_per_kwh"] for s, p in zip(shares, intervals))
        intensity = g / 1000
        first = math.floor(start / 3600) * 3600 - HOURS_AROUND * 3600
        last = math.ceil(end / 3600) * 3600 + HOURS_AROUND * 3600
        hours = {}
        for p in points:
            begin = stamp(p["datetime"])
            v = p["g_per_kwh"]
            if v is None or isinstance(v, bool) or not (first <= begin < last):
                continue
            hours[begin] = (float(v), bool(p.get("estimated")))
        estimated = any(p["estimated"] for p in intervals)
        pieces = ", ".join(f"{hour_text(p['source_start'])[11:16]} UTC {p['g_per_kwh']:.0f} g/kWh x {s:.1%}"
                           for p, s in zip(intervals, shares))
        new.update({
            "rm:carbonIntensityAssumptionKgCO2ePerKWh": [lit(intensity)],
            "rm:carbonEmissionKgCO2e": [lit(energy_kwh * intensity)],
            "rm:carbonIntensitySource": [lit(f"Electricity Maps {unit_s} history (zone DE, lifecycle, flow-traced)")],
            "rm:carbonIntensitySourceLink": [lit(source_url, "xsd:anyURI")],
            "rm:carbonIntensityWindowStart": [lit(datetime.fromtimestamp(intervals[0]["source_start"], UTC)
                                                  .strftime("%Y-%m-%dT%H:%M:%SZ"), "xsd:dateTime")],
            "rm:carbonIntensityWindowEnd": [lit(datetime.fromtimestamp(intervals[-1]["source_end"], UTC)
                                                .strftime("%Y-%m-%dT%H:%M:%SZ"), "xsd:dateTime")],
            "rm:carbonIntensityDataPointCount": [lit(len(intervals), "xsd:integer")],
            "rm:carbonIntensityIncludesEstimatedData": [lit(estimated)],
            "rm:carbonIntensityEmissionsBasis": [lit("lifecycle CO2e")],
            "rm:carbonIntensityTemporalGranularity": [lit(granularity)],
            "rm:carbonCalculationMethod": [lit(
                f"Time-matched: the run's energy {energy_kwh:.6f} kWh x the {unit_s} carbon intensity of the German "
                f"grid (Electricity Maps, lifecycle, flow-traced) in the {unit}s the run used, weighted by the run's "
                f"energy in each {unit} ({pieces}) = {g:.1f} g/kWh, so {energy_kwh * intensity * 1000:.2f} g CO2e.")],
        })
        if len(hours) >= 2:
            ordered = sorted(hours)
            text = "; ".join(f"{hour_text(b)} {hours[b][0]:.1f}{'*' if hours[b][1] else ''}" for b in ordered)
            new["rm:gridCarbonIntensityHours"] = [lit(text)]
            new["rm:gridCarbonIntensityHoursMethod"] = [lit(
                f"Hourly carbon intensity of the German grid (zone DE) from Electricity Maps (lifecycle CO2e, "
                f"flow-traced), in grams per kWh, for the {len(hours)} hours from {hour_text(ordered[0])} to "
                f"{hour_text(ordered[-1] + 3600)} (UTC) that its history returned when this record was made. Each entry "
                f"is the start of an hour and its intensity. Shown on the run page next to the hour or hours the run used.")]
    except (Stop, ValueError, KeyError, urllib.error.URLError, OSError) as exc:
        carbon_note = f"carbon not time-matched ({exc}); the run's intensity is kept and applied to the new energy"
        old_intensity = values.get("rm:carbonIntensityAssumptionKgCO2ePerKWh")
        if old_intensity:
            intensity = float(old_intensity[0])
            new["rm:carbonEmissionKgCO2e"] = [lit(energy_kwh * intensity)]
            old_method = (values.get("rm:carbonCalculationMethod") or [""])[0]
            new["rm:carbonCalculationMethod"] = [lit(
                (old_method + " " if old_method else "") + f"Applied to the whole-node energy {energy_kwh:.6f} kWh: "
                f"{energy_kwh * intensity * 1000:.2f} g CO2e.")]

    run_lines = resources[run]
    for predicate in new:
        removed += [line for p, _, line in run_lines if p == predicate]
    summary = dict(run=run, node=node, start_utc=datetime.fromtimestamp(start, UTC).isoformat(),
                   duration_s=round(duration), node_energy_kwh=energy_kwh, previous_energy_kwh=old_energy,
                   idle_w=round(idle_w, 1), above_idle_kwh=above_kwh, readings=len(readings),
                   quiet_windows=windows, grid_hours="rm:gridCarbonIntensityHours" in new,
                   carbon_note=carbon_note, warnings=warnings)
    return run, new, removed, summary


def write_ttl(path, prefixes, run, lines, header):
    body = "\n".join(lines)
    path.write_text(f"# {header}\n{prefixes}\n{run}\n{body}\n" if lines else f"# {header}\n# nothing\n")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--ttl", required=True, help="the run's Turtle file from the publisher outbox")
    parser.add_argument("--prom-url", default="http://localhost:19090", help="Prometheus (port-forward)")
    parser.add_argument("--namespace", default="yagmur", help="namespace of the electricity-maps-api-token secret")
    parser.add_argument("--token", default="", help=argparse.SUPPRESS)
    parser.add_argument("--out-dir", default=".")
    parser.add_argument("--allow-shared", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--now", type=float, default=None, help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    try:
        run, new, removed, summary = build(args)
    except Stop as exc:
        print("STOP: " + str(exc), file=sys.stderr)
        return 2
    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    prefixes = "\n".join(line for line in Path(args.ttl).read_text().splitlines() if line.startswith("@prefix"))
    stem = Path(args.ttl).name.rsplit(".ttl", 1)[0]
    # A file from an earlier pass for this run: its values may be in VIVO, so they are removed too;
    # the earlier files are kept as *.prev-STAMP.
    previous_add = out / f"{stem}-node-power_ADD.ttl"
    if previous_add.exists():
        earlier = read_ttl(previous_add.read_text()).get(run, [])
        known = {(p, o) for p, o, _ in read_ttl("\n".join([run] + removed)).get(run, [])}
        removed = removed + [line for p, o, line in earlier if (p, o) not in known]
        mark = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
        for kind in ("ADD", "REMOVE"):
            old = out / f"{stem}-node-power_{kind}.ttl"
            if old.exists():
                old.rename(out / f"{stem}-node-power_{kind}.ttl.prev-{mark}")
        print(f"Earlier files of this run kept as *.prev-{mark}; their {len(earlier)} added values are in the new "
              "REMOVE file, so uploading REMOVE then ADD replaces them.")
    add_lines = []
    flat = [(p, o) for p, objs in new.items() for o in objs]
    for i, (p, o) in enumerate(flat):
        add_lines.append(f"  {p} {o} {'.' if i == len(flat) - 1 else ';'}")
    remove_lines = []
    for i, line in enumerate(removed):
        body = line.rstrip()
        body = body[:-2] if body.endswith((" ;", " .")) else body
        remove_lines.append(f"{body} {'.' if i == len(removed) - 1 else ';'}")
    write_ttl(out / f"{stem}-node-power_REMOVE.ttl", prefixes, run, remove_lines,
              "Upload FIRST: Site Admin > Add/Remove RDF data > remove mixed RDF, format Turtle")
    write_ttl(out / f"{stem}-node-power_ADD.ttl", prefixes, run, add_lines,
              "Upload SECOND: Site Admin > Add/Remove RDF data > add mixed RDF, format Turtle")
    (out / f"{stem}-node-power.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({k: summary[k] for k in ("node", "duration_s", "node_energy_kwh", "previous_energy_kwh",
                                              "idle_w", "above_idle_kwh", "readings", "grid_hours", "carbon_note",
                                              "warnings")}, indent=2))
    for w in summary["warnings"]:
        print("WARNING: " + w, file=sys.stderr)
    print(f"REMOVE: {out / (stem + '-node-power_REMOVE.ttl')} ({len(remove_lines)} triples)")
    print(f"ADD:    {out / (stem + '-node-power_ADD.ttl')} ({len(add_lines)} triples)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
