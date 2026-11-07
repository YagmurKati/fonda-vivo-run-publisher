#!/usr/bin/env python3
"""Recalculate the carbon of the 100 nf-core/rangeland runs of the Mid4CC '26 paper with 15-minute
grid carbon intensity from Electricity Maps (zone DE, lifecycle, flow-traced).

Input:  the N-Triples export of the runs' current values (query 1_export.rq on the VIVO SPARQL page).
Output: carbon15_REMOVE.nt  current carbon triples of the 100 runs and their steps (also the backup)
        carbon15_ADD.nt     the new triples
        carbon15_report.csv old and new value of every run

Method, as in the collectors, with quarter-hours instead of hours: the run's energy is split across the
quarter-hours it covers by its node power readings (by time if there are fewer than two readings), each part
is multiplied by the intensity of its quarter-hour, and the parts are added. Step carbon of HPC@HU runs is scaled
by the same factor as its run, so step values still add up to the run value. Fonda step values are not changed.

Usage:  ELECTRICITY_MAPS_API_TOKEN=... python3 carbon_15min.py export.nt
Only the standard library is needed. The token is read from the environment and never written to a file.
"""
import csv
import json
import math
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

RM = "http://example.org/ontology/run-metadata#"
XSD = "http://www.w3.org/2001/XMLSchema#"
BERLIN = ZoneInfo("Europe/Berlin")
API = "https://api.electricitymaps.com/v4/carbon-intensity/past-range"
ZONE = "DE"
STEP = 900  # 15 minutes
TODAY = "2026-11-07"

# Carbon properties of a run that are replaced (only those present are removed).
RUN_CARBON = ["carbonEmissionKgCO2e", "carbonIntensityAssumptionKgCO2ePerKWh", "carbonIntensitySource",
              "carbonIntensitySourceLink", "carbonIntensityWindowStart", "carbonIntensityWindowEnd",
              "carbonIntensityDataPointCount", "carbonIntensityIncludesEstimatedData",
              "carbonIntensityTemporalGranularity", "carbonCalculationMethod"]

HERE = Path(__file__).resolve().parent
RUNS = [line.strip() for line in (HERE / "runs100.txt").read_text().splitlines() if line.strip()]

TRIPLE = re.compile(r'^(<[^>]*>)\s+(<[^>]*>)\s+(.*\S)\s*\.\s*$')
LITERAL = re.compile(r'^"((?:[^"\\]|\\.)*)"(?:\^\^<([^>]*)>|@([A-Za-z0-9-]+))?$')


def unescape(text):
    def rep(m):
        c = m.group(1)
        if c.startswith("u") or c.startswith("U"):
            return chr(int(c[1:], 16))
        return {"n": "\n", "r": "\r", "t": "\t", '"': '"', "\\": "\\", "'": "'"}.get(c, c)
    return re.sub(r'\\(u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8}|.)', rep, text)


def escape(text):
    return (text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r"))


def parse(path):
    """{subject: {predicate: [(line, value, datatype)]}} for the export file."""
    data = defaultdict(lambda: defaultdict(list))
    for raw in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = TRIPLE.match(line)
        if not m:
            raise SystemExit(f"not an N-Triples line (export the query as N-Triples): {line[:120]}")
        s, p, o = m.group(1)[1:-1], m.group(2)[1:-1], m.group(3)
        lit = LITERAL.match(o)
        if lit:
            value, dtype = unescape(lit.group(1)), lit.group(2)
        else:
            value, dtype = o[1:-1], "IRI"
        data[s][p].append((line, value, dtype))
    return data


def one(values, name, required=True):
    items = values.get(RM + name, [])
    if len(items) > 1 and len({v for _, v, _ in items}) > 1:
        raise ValueError(f"{name} has {len(items)} different values")
    if not items:
        if required:
            raise ValueError(f"{name} missing")
        return None
    return items[0]


def local_to_epoch(value):
    """rm:startTime / rm:endTime are Europe/Berlin local times without offset."""
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=BERLIN)
    return parsed.timestamp()


def berlin(epoch):
    return datetime.fromtimestamp(epoch, BERLIN).replace(tzinfo=None).isoformat(timespec="seconds")


def utc(epoch):
    return datetime.fromtimestamp(epoch, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def readings_of(values, start):
    """[(epoch, watts)] from rm:nodePowerReadings; offsets count from the start named in the method text."""
    item = one(values, "nodePowerReadings", required=False)
    if not item:
        return []
    ref = start
    method = one(values, "nodePowerReadingsMethod", required=False)
    if method:
        m = re.search(r"started \(?(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?(?:Z|[+-]\d\d:\d\d))", method[1])
        if m:
            ref = datetime.fromisoformat(m.group(1).replace("Z", "+00:00")).timestamp()
    out = []
    for part in item[1].split(";"):
        bits = part.split()
        if len(bits) >= 2:
            out.append((ref + float(bits[0]), float(bits[1])))
    return sorted(out)


_cache = {}


def fetch_day(token, day_start):
    """All 15-minute points of one UTC day (cached)."""
    if day_start in _cache:
        return _cache[day_start]
    params = {"zone": ZONE, "start": utc(day_start), "end": utc(day_start + 86400),
              "temporalGranularity": "15_minutes", "emissionFactorType": "lifecycle"}
    url = API + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"auth-token": token, "User-Agent": "fonda-vivo-carbon15"})
    for attempt in range(4):
        try:
            try:
                with urllib.request.urlopen(req, timeout=60) as resp:
                    payload = json.load(resp)
            except urllib.error.URLError as exc:
                if "CERTIFICATE" not in str(exc).upper():
                    raise
                # Python without certificates (common on macOS): ask curl instead.
                out = subprocess.run(["curl", "-sS", "--fail", "-H", f"auth-token: {token}", url],
                                     capture_output=True, text=True, timeout=90, check=True).stdout
                payload = json.loads(out)
            break
        except Exception as exc:  # network or rate limit: wait and try again
            if attempt == 3:
                raise SystemExit(f"Electricity Maps request failed for {utc(day_start)}: {exc}")
            time.sleep(5 * (attempt + 1))
    if payload.get("zone") != ZONE or payload.get("temporalGranularity") != "15_minutes":
        raise SystemExit(f"unexpected answer for {utc(day_start)}: zone {payload.get('zone')}, "
                         f"granularity {payload.get('temporalGranularity')}")
    points = {}
    for row in payload.get("data", []):
        if row.get("emissionFactorType") != "lifecycle" or row.get("flowTraced") is not True:
            raise SystemExit(f"unexpected emissions basis at {row.get('datetime')}")
        value = row.get("carbonIntensity")
        if value is None or isinstance(value, bool):
            continue
        begin = datetime.fromisoformat(str(row["datetime"]).replace("Z", "+00:00")).timestamp()
        points[begin] = (float(value), bool(row.get("isEstimated", False)))
    _cache[day_start] = points
    time.sleep(0.5)
    return points


def quarters(token, start, end):
    """The quarter-hours that cover every instant of the run, cut to the run."""
    pieces = []
    q = math.floor(start / STEP) * STEP
    while q < end:
        day = math.floor(q / 86400) * 86400
        point = fetch_day(token, day).get(q)
        if point is None:
            raise ValueError(f"no 15-minute intensity for {utc(q)}")
        pieces.append({"begin": q, "start": max(q, start), "end": min(q + STEP, end),
                       "g": point[0], "estimated": point[1]})
        q += STEP
    return pieces


def shares(pieces, readings):
    """Share of the run's energy in each piece, from the power readings (by time if fewer than two)."""
    def energy_in(a, b):
        total = 0.0
        for (t0, w0), (t1, w1) in zip(readings, readings[1:]):
            lo, hi = max(a, t0), min(b, t1)
            if hi <= lo or t1 <= t0:
                continue
            f0 = w0 + (w1 - w0) * (lo - t0) / (t1 - t0)
            f1 = w0 + (w1 - w0) * (hi - t0) / (t1 - t0)
            total += (f0 + f1) / 2 * (hi - lo)
        return total
    parts, basis = None, "time"
    if len(readings) >= 2:
        parts = [energy_in(p["start"], p["end"]) for p in pieces]
        basis = "power readings"
        if sum(parts) <= 0:
            parts = None
    if parts is None:
        parts, basis = [p["end"] - p["start"] for p in pieces], "time"
    total = sum(parts)
    return [x / total for x in parts], basis


def lit(value, dtype=None):
    if isinstance(value, bool):
        return f'"{str(value).lower()}"^^<{XSD}boolean>'
    if isinstance(value, int):
        return f'"{value}"^^<{dtype or XSD + "integer"}>'
    if isinstance(value, float):
        return f'"{repr(value)}"^^<{dtype or XSD + "double"}>'
    return f'"{escape(value)}"' + (f"^^<{dtype}>" if dtype else "")


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    token = os.environ.get("ELECTRICITY_MAPS_API_TOKEN", "").strip()
    if not token:
        raise SystemExit("set ELECTRICITY_MAPS_API_TOKEN first")
    data = parse(sys.argv[1])
    missing = [r for r in RUNS if r not in data]
    if missing:
        raise SystemExit(f"{len(missing)} of the 100 runs are not in the export, e.g. {missing[0]}")
    remove, add, report = [], [], []
    for run in RUNS:
        values = data[run]
        start = local_to_epoch(one(values, "startTime")[1])
        end = local_to_epoch(one(values, "endTime")[1])
        energy = float(one(values, "energyKWh")[1])
        old_kg = float(one(values, "carbonEmissionKgCO2e")[1])
        old_i = one(values, "carbonIntensityAssumptionKgCO2ePerKWh", required=False)
        old_g = float(old_i[1]) * 1000 if old_i else (old_kg / energy * 1000 if energy else float("nan"))
        if end <= start or energy <= 0:
            raise SystemExit(f"{run}: no time span or energy")
        pieces = quarters(token, start, end)
        fractions, basis = shares(pieces, readings_of(values, start))
        g = sum(f * p["g"] for f, p in zip(fractions, pieces))
        kg = energy * g / 1000  # kWh x g/kWh = g CO2e; / 1000 = kg CO2e
        factor = kg / old_kg if old_kg else None
        detail = ", ".join(f"{utc(p['begin'])[11:16]} UTC {p['g']:.0f} g/kWh x {f:.1%}"
                           for p, f in zip(pieces, fractions))
        dtype = lambda name, default: (one(values, name, required=False) or (None, None, default))[2] or default
        link = API + "?" + urllib.parse.urlencode({
            "zone": ZONE, "start": utc(pieces[0]["begin"]), "end": utc(pieces[-1]["begin"] + STEP),
            "temporalGranularity": "15_minutes", "emissionFactorType": "lifecycle"})
        new = {
            "carbonEmissionKgCO2e": lit(kg, dtype("carbonEmissionKgCO2e", XSD + "double")),
            "carbonIntensityAssumptionKgCO2ePerKWh": lit(g / 1000, dtype("carbonIntensityAssumptionKgCO2ePerKWh",
                                                                          XSD + "double")),
            "carbonIntensitySource": lit(f"Electricity Maps 15-minute history (zone {ZONE}, lifecycle, flow-traced)"),
            "carbonIntensitySourceLink": lit(link, XSD + "anyURI"),
            "carbonIntensityWindowStart": lit(berlin(pieces[0]["begin"]), XSD + "dateTime"),
            "carbonIntensityWindowEnd": lit(berlin(pieces[-1]["begin"] + STEP), XSD + "dateTime"),
            "carbonIntensityDataPointCount": lit(len(pieces), dtype("carbonIntensityDataPointCount",
                                                                    XSD + "integer")),
            "carbonIntensityIncludesEstimatedData": lit(any(p["estimated"] for p in pieces)),
            "carbonIntensityTemporalGranularity": lit("15 minutes"),
            "carbonCalculationMethod": lit(
                f"Time-matched: the run's energy {energy:.6f} kWh x the 15-minute carbon intensity of the grid "
                f"(Electricity Maps, zone {ZONE}, lifecycle, flow-traced) in the quarter-hours the run used, "
                f"weighted by the run's energy in each quarter-hour (split by {basis}; {detail}) = {g:.1f} g/kWh, "
                f"so {kg * 1000:.2f} g CO2e. Window start and end are Europe/Berlin times. Recalculated on {TODAY}: "
                f"replaces the earlier value {old_kg * 1000:.2f} g CO2e ({old_g:.1f} g/kWh)."),
        }
        for name in RUN_CARBON:
            remove += [line for line, _, _ in values.get(RM + name, [])]
            add.append(f"<{run}> <{RM}{name}> {new[name]} .")
        # Only HPC@HU steps: their carbon is defined as the job's carbon x the step's CPU share. Fonda step
        # values come from per-pod Kepler readings with their own factor and are left as they are.
        steps = [v for _, v, _ in values.get(RM + "hasWorkflowProcess", [])] if "hpc-at-hu-slurm" in run else []
        changed_steps = 0
        for step in steps:
            for line, value, dt in data.get(step, {}).get(RM + "carbonEmissionKgCO2e", []):
                if factor is None:
                    raise SystemExit(f"{run}: old carbon is zero, cannot scale its steps")
                remove.append(line)
                add.append(f"<{step}> <{RM}carbonEmissionKgCO2e> {lit(float(value) * factor, dt or XSD + 'double')} .")
                changed_steps += 1
        report.append({"run": run, "cluster": "Fonda" if "hpc-at-hu" not in run else "HPC@HU",
                       "start_berlin": berlin(start), "energy_kwh": f"{energy:.6g}",
                       "old_g_per_kwh": f"{old_g:.1f}", "new_g_per_kwh": f"{g:.1f}",
                       "old_g_co2e": f"{old_kg * 1000:.4f}", "new_g_co2e": f"{kg * 1000:.4f}",
                       "change_percent": f"{(kg / old_kg - 1) * 100:+.2f}" if old_kg else "",
                       "quarter_hours": len(pieces), "split_by": basis, "steps_rescaled": changed_steps})
    Path("carbon15_REMOVE.nt").write_text("\n".join(remove) + "\n", encoding="utf-8")
    Path("carbon15_ADD.nt").write_text("\n".join(add) + "\n", encoding="utf-8")
    with open("carbon15_report.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(report[0]))
        w.writeheader()
        w.writerows(report)
    changes = [float(r["change_percent"]) for r in report if r["change_percent"]]
    print(f"{len(report)} runs: {len(remove)} triples to remove, {len(add)} to add. "
          f"Carbon change per run: {min(changes):+.2f}% to {max(changes):+.2f}%, "
          f"mean {sum(changes) / len(changes):+.2f}%.")
    print("Wrote carbon15_REMOVE.nt, carbon15_ADD.nt, carbon15_report.csv")


if __name__ == "__main__":
    main()
