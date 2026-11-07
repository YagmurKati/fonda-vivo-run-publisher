"""Time-matched grid emissions for measured RAPL energy; no proxy fallback."""
import base64
from datetime import datetime, timedelta, timezone
import json
import math
import os
import subprocess
import urllib.error
import urllib.parse
import urllib.request

UTC = timezone.utc


# Time resolutions of the grid data, tried in this order: 15-minute values where the account and the zone
# offer them, hourly values otherwise.
GRANULARITY_SECONDS = {"15_minutes": 900, "hourly": 3600}
GRANULARITY_LABEL = {"15_minutes": "15 minutes", "hourly": "hourly"}


class CarbonUnavailable(ValueError):
    def __init__(self, message, attempts):
        super().__init__(message)
        self.attempts = attempts


def stamp(value):
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("Carbon data timestamp has no timezone")
    return parsed.timestamp()


def iso(value):
    return datetime.fromtimestamp(value, UTC).isoformat()


def covered_intervals(points, start, end):
    """Require contiguous records (15 minutes or hourly) covering every instant of the run."""
    selected = []
    for point in points:
        begin = stamp(point["datetime"])
        finish = begin + point.get("seconds", 3600)
        if finish <= start or begin >= end:
            continue
        value = point["g_per_kwh"]
        if isinstance(value, bool) or value is None:
            raise ValueError("Missing or invalid carbon intensity")
        value = float(value)
        if not math.isfinite(value) or value < 0:
            raise ValueError("Invalid carbon intensity")
        selected.append(dict(start=max(begin, start), end=min(finish, end),
                             source_start=begin, source_end=finish, g_per_kwh=value,
                             estimated=bool(point.get("estimated", False))))
    selected.sort(key=lambda point: point["start"])
    cursor = start
    for point in selected:
        if not math.isclose(point["start"], cursor, abs_tol=1e-6, rel_tol=0):
            raise ValueError("Carbon data has a gap or overlapping records")
        cursor = point["end"]
    if not selected or not math.isclose(cursor, end, abs_tol=1e-6, rel_tol=0):
        raise ValueError("Carbon data does not cover the run's complete time interval")
    return selected


def calculate(intervals, energy_between):
    records = []
    for point in intervals:
        energy = energy_between(point["start"], point["end"])
        row = dict(point)
        for domain in ("package", "dram"):
            kwh = energy[domain] / 3_600_000
            if not math.isfinite(kwh) or kwh < 0:
                raise ValueError("Invalid measured energy")
            row[domain + "_kwh"] = kwh
            row[domain + "_kg"] = kwh * point["g_per_kwh"] / 1000
        records.append(row)
    package_kwh = sum(row["package_kwh"] for row in records)
    if package_kwh <= 0:
        raise ValueError("No measured package energy")
    package_kg = sum(row["package_kg"] for row in records)
    return dict(status="time-matched", package_kg=package_kg,
                dram_kg=sum(row["dram_kg"] for row in records),
                intensity_kg_per_kwh=package_kg / package_kwh,
                package_kwh=package_kwh, intervals=records,
                start_utc=iso(intervals[0]["start"]), end_utc=iso(intervals[-1]["end"]),
                source_window_start=iso(intervals[0]["source_start"]),
                source_window_end=iso(intervals[-1]["source_end"]),
                includes_estimates=any(point["estimated"] for point in intervals))


def electricity_points(payload, granularity=None):
    resolution = payload.get("temporalGranularity")
    if payload.get("zone") != "DE" or resolution not in GRANULARITY_SECONDS or \
            (granularity is not None and resolution != granularity):
        raise ValueError("Unexpected Electricity Maps zone or time resolution")
    rows = payload.get("history", payload.get("data"))
    if not isinstance(rows, list):
        raise ValueError("No Electricity Maps data")
    result = []
    for row in rows:
        if row.get("zone", "DE") != "DE" or row.get("emissionFactorType") != "lifecycle" or row.get("flowTraced") is not True:
            raise ValueError("Unexpected Electricity Maps emissions basis")
        result.append(dict(datetime=row["datetime"], g_per_kwh=row.get("carbonIntensity", row.get("value")),
                           estimated=row.get("isEstimated", False), seconds=GRANULARITY_SECONDS[resolution]))
    return result


def co2map_points(payload):
    if payload.get("state") != "DE" or payload.get("country") != "DE" or payload.get("unit") != "g/kWh":
        raise ValueError("Unexpected CO2Map zone or unit")
    series = [v for k, v in payload.items() if k.startswith("Consumption-based Intensity")]
    if len(series) != 1 or not isinstance(series[0], list):
        raise ValueError("No hourly CO2Map data")
    return [dict(datetime=row[0], g_per_kwh=row[1], estimated=True, seconds=3600) for row in series[0]]


def api_token(namespace):
    token = os.environ.get("ELECTRICITY_MAPS_API_TOKEN", "").strip()
    if token:
        return token
    try:
        process = subprocess.run(["kubectl", "--request-timeout=15s", "-n", namespace,
                                  "get", "secret", "electricity-maps-api-token", "-o", "json"],
                                 capture_output=True, text=True, timeout=20)
        if process.returncode == 0:
            return base64.b64decode(json.loads(process.stdout)["data"]["token"]).decode().strip()
    except (OSError, subprocess.TimeoutExpired, ValueError, KeyError):
        pass
    return ""


def fetch_carbon(summary, energy_between):
    start, end = stamp(summary["start_utc"]), stamp(summary["end_utc"])
    token = api_token(summary["namespace"])
    attempts = []
    sources = []
    if token:
        for granularity, seconds in GRANULARITY_SECONDS.items():
            def parse_em(payload, granularity=granularity):
                return electricity_points(payload, granularity)
            parameters = dict(zone="DE", temporalGranularity=granularity, emissionFactorType="lifecycle",
                              flowTraced="true")
            sources.append(("Electricity Maps", "https://api.electricitymaps.com/v4/carbon-intensity/history",
                            parameters, {"auth-token": token}, parse_em, "lifecycle CO2e"))
            parameters = dict(parameters, start=iso(math.floor(start / seconds) * seconds),
                              end=iso(math.ceil(end / seconds) * seconds))
            sources.append(("Electricity Maps", "https://api.electricitymaps.com/v4/carbon-intensity/past-range",
                            parameters, {"auth-token": token}, parse_em, "lifecycle CO2e"))
    for status in ("Preliminary", "Historical"):
        sources.append(("CO2Map.de", "https://api.co2map.de/ConsumptionIntensity" + status + "/",
                        dict(state="DE", country="DE", start=datetime.fromtimestamp(start, UTC).date().isoformat(),
                             end=(datetime.fromtimestamp(end, UTC).date() + timedelta(days=1)).isoformat()),
                        {}, co2map_points, "direct CO2"))
    for name, endpoint, parameters, headers, parse, basis in sources:
        url = endpoint + "?" + urllib.parse.urlencode(parameters)
        attempt = dict(source=name, source_url=url, retrieved_at_utc=datetime.now(UTC).isoformat())
        attempts.append(attempt)
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30) as response:
                payload = json.load(response)
            attempt["payload"] = payload
            intervals = covered_intervals(parse(payload), start, end)
            result = calculate(intervals, energy_between)
            if not math.isclose(result["package_kwh"], summary["energy_kwh"], rel_tol=1e-8, abs_tol=1e-12):
                raise ValueError("Interval energy does not sum to the measured run energy")
            granularity = GRANULARITY_LABEL.get(parameters.get("temporalGranularity"), "hourly")
            result.update(source=name, source_url=url, basis=basis, zone="DE", temporal_granularity=granularity,
                          retrieved_at_utc=attempt["retrieved_at_utc"], attempts=attempts)
            return result
        except urllib.error.HTTPError as exc:
            attempt["error"] = "HTTP " + str(exc.code)
        except (urllib.error.URLError, TimeoutError, OSError, ValueError, KeyError, TypeError) as exc:
            # Never include request headers, credentials or provider error bodies.
            attempt["error"] = str(exc) if isinstance(exc, ValueError) else type(exc).__name__
    raise CarbonUnavailable("No carbon-intensity data covers this run. Publication stopped; retry collection when matching data is available.", attempts)


def require_carbon(summary):
    carbon = summary.get("carbon", {})
    if carbon.get("status") != "time-matched":
        raise ValueError("Publication requires carbon data matched to the run's execution time; recollect metadata")
    if carbon.get("start_utc") != summary["start_utc"] or carbon.get("end_utc") != summary["end_utc"]:
        raise ValueError("Carbon accounting interval differs from the workflow interval")
    return carbon
