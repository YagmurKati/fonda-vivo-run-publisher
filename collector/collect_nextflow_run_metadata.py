#!/usr/bin/env python3
"""Collect VIVO-ready metadata for one Nextflow run on Kubernetes."""

import argparse
import csv
import hashlib
import io
import json
import math
import os
import re
import shlex
import shutil
import ssl
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from dataclasses import asdict, dataclass, field, fields
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Set, Tuple
from zoneinfo import ZoneInfo


PROM_URL_DEFAULT = "http://127.0.0.1:19090"
CARBON_INTENSITY_DEFAULT = 0.4
BASE_URI_DEFAULT = "http://example.org/vivo-import/run-metadata/"
ONTOLOGY_URI_DEFAULT = "http://example.org/ontology/run-metadata#"

DEFAULT_NAMESPACE = "default"
DEFAULT_DRIVER_POD = "nextflow-driver"
DEFAULT_WORKFLOW_NAME = "Example Nextflow workflow"
DEFAULT_WORKFLOW_URI = (
    "http://example.org/vivo-import/run-metadata/workflow/replace-me"
)
DEFAULT_PUBLICATION_URI = ""
DEFAULT_CODE_URI = ""
# Repository the workflow source (and therefore the git commit) belongs to.
# Used to build a clickable commit URL; keep separate from DEFAULT_CODE_URI,
# which points at this metadata-collector repo.
DEFAULT_WORKFLOW_REPO_URL = ""
DEFAULT_TRACE_ARCHIVE = ""
DEFAULT_WORKFLOW_TRACE_REPOSITORY = ""
DEFAULT_RUN_TRACE_ARCHIVE = ""
DEFAULT_APPLICATION_DOMAIN_URI = ""
DEFAULT_RUN_OPERATOR_URI = ""
# Emptied 2026-07-30: literal researcher names are no longer emitted (see the
# note in the workflow-predicate builder). To credit Florian Katerndahl and
# Dirk Pflugmacher, add their VIVO person URIs to
# DEFAULT_RESPONSIBLE_RESEARCHER_URIS below.
DEFAULT_RESPONSIBLE_RESEARCHERS: List[str] = []
DEFAULT_RESPONSIBLE_RESEARCHER_URIS: List[str] = []
DEFAULT_SUBPROJECT_URIS: List[str] = []
DEFAULT_LANGUAGE_URIS: List[str] = []
DEFAULT_LANGUAGE_LABELS = {
    "http://example.org/vivo-import/run-metadata/language/python": "Python",
    "http://example.org/vivo-import/run-metadata/language/shell": "Shell",
}
DEFAULT_CLUSTER_URI = "http://example.org/vivo-import/run-metadata/cluster/fonda-cluster"
# What the Kepler energy of a pod contains on the FONDA cluster.
FONDA_KEPLER_IDLE_NOTE = (
    " Idle power is included: Kepler on the FONDA cluster does not report "
    "idle energy separately (checked on 2026-10-04). It divides the energy "
    "it measures on a node (CPU, memory and, from the node's power meter, "
    "the rest of the machine such as fans and power supply) among the pods "
    "on that node. The value is therefore not independent of node "
    "temperature."
)
DEFAULT_ENGINE_URI = "http://example.org/vivo-import/run-metadata/engine/nextflow"
DEFAULT_BACKEND_URI = ""
DEFAULT_OUTPUT_STEM = "fonda-nextflow-run-metadata"
DEFAULT_TRACE_TYPES = "Nextflow trace, execution report, timeline, and execution logs"
DEFAULT_TRACE_DATA_FORMAT = "TSV, HTML, and plain text"

REQUIRED_NODE_METADATA = (
    ("allocatable", "cpu", "allocatable CPU"),
    ("allocatable", "memory", "allocatable memory"),
    ("node_info", "architecture", "architecture"),
    ("node_info", "osImage", "OS image"),
    ("node_info", "kernelVersion", "kernel version"),
    ("node_info", "kubeletVersion", "kubelet version"),
)

BERLIN_TZ = ZoneInfo("Europe/Berlin")
MONTHS = {
    "Jan": 1,
    "Feb": 2,
    "Mar": 3,
    "Apr": 4,
    "May": 5,
    "Jun": 6,
    "Jul": 7,
    "Aug": 8,
    "Sep": 9,
    "Oct": 10,
    "Nov": 11,
    "Dec": 12,
}
LOG_TS_RE = re.compile(
    r"^(?P<month>[A-Z][a-z]{2})-(?P<day>\d{2}) "
    r"(?P<time>\d{2}:\d{2}:\d{2}\.\d+)"
)
# Nextflow logs "Session uuid:" up to the 21.x line and "Session UUID:"
# afterwards. Match case-insensitively so a run launched with an older
# Nextflow keeps its session identity in the run URI.
SESSION_RE = re.compile(r"Session UUID:\s*(\S+)", re.IGNORECASE)
RUN_NAME_RE = re.compile(r"Run name:\s*(\S+)")
NEXTFLOW_VERSION_RE = re.compile(r"N E X T F L O W\s+~\s+version\s+(\S+)")
CONTAINER_RE = re.compile(r"(?m)^\s*container\s*=\s*['\"]([^'\"]+)['\"]")


@dataclass
class TaskRecord:
    task_id: str
    hash_value: str
    pod_name: Optional[str]
    name: str
    status: str
    exit_code: Optional[int]
    submit: datetime
    duration_seconds: Optional[float]
    realtime_seconds: Optional[float]
    cpu_percent: Optional[float] = None
    peak_rss_bytes: Optional[float] = None
    start: Optional[datetime] = None
    end: Optional[datetime] = None

    @property
    def trace_cpu_seconds(self) -> Optional[float]:
        """Return executor CPU seconds from realtime multiplied by %cpu."""
        if self.realtime_seconds is None or self.cpu_percent is None:
            return None
        return self.realtime_seconds * self.cpu_percent / 100.0


@dataclass
class PodMetrics:
    pod_name: str
    cpu_seconds: Optional[float] = None
    cpu_query: Optional[str] = None
    cpu_method: Optional[str] = None
    energy_joules: Optional[float] = None
    energy_query: Optional[str] = None
    energy_method: Optional[str] = None
    energy_estimated: bool = False
    memory_series: Dict[int, float] = field(default_factory=dict)
    memory_query: Optional[str] = None
    node_name: Optional[str] = None
    images: List[str] = field(default_factory=list)


@dataclass
class CarbonIntensityInfo:
    kg_per_kwh: float
    source: str
    source_uri: Optional[str] = None
    zone: Optional[str] = None
    point_count: int = 0
    includes_estimates: bool = False
    start: Optional[str] = None
    end: Optional[str] = None
    emissions_basis: str = "CO2e"
    temporal_granularity: Optional[str] = None
    method_note: Optional[str] = None


@dataclass(frozen=True)
class InputDatasetMetadata:
    uri: str
    label: str
    description: Optional[str] = None
    access_instructions_url: Optional[str] = None
    checksum_manifest_url: Optional[str] = None
    upstream_source_url: Optional[str] = None
    upstream_source_urls: Tuple[str, ...] = ()
    format_documentation_url: Optional[str] = None
    storage_location: Optional[str] = None
    access_statement: Optional[str] = None
    link_to_workflow: bool = True
    link_to_run: bool = True


def run_cmd(args: Sequence[str], check: bool = True) -> str:
    proc = subprocess.run(args, text=True, capture_output=True)
    if check and proc.returncode != 0:
        command = " ".join(shlex.quote(part) for part in args)
        raise RuntimeError(f"Command failed: {command}\n{proc.stderr.strip()}")
    return proc.stdout


def kubectl_json(args: Sequence[str]) -> Dict[str, Any]:
    if shutil.which("kubectl"):
        output = run_cmd(["kubectl", *args, "-o", "json"])
        return json.loads(output)

    # The cluster-side metadata Job intentionally uses the Kubernetes API
    # directly so its image does not need to contain a kubectl binary. The
    # collector currently needs this fallback only for node information.
    if len(args) == 3 and args[:2] == ["get", "node"]:
        host = os.environ.get("KUBERNETES_SERVICE_HOST")
        port = os.environ.get("KUBERNETES_SERVICE_PORT_HTTPS", "443")
        token_path = Path(
            "/var/run/secrets/kubernetes.io/serviceaccount/token"
        )
        ca_path = Path(
            "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
        )
        if not host or not token_path.is_file() or not ca_path.is_file():
            raise RuntimeError(
                "kubectl is unavailable and no in-cluster service account "
                "credentials were found"
            )
        node_name = urllib.parse.quote(args[2], safe="")
        request = urllib.request.Request(
            f"https://{host}:{port}/api/v1/nodes/{node_name}",
            headers={
                "Accept": "application/json",
                "Authorization": (
                    "Bearer "
                    + token_path.read_text(encoding="utf-8").strip()
                ),
            },
        )
        context = ssl.create_default_context(cafile=str(ca_path))
        try:
            with urllib.request.urlopen(
                request, timeout=30, context=context
            ) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"Kubernetes API returned HTTP {exc.code}: {detail}"
            ) from exc

    raise RuntimeError(
        "kubectl is unavailable and this Kubernetes operation has no "
        f"in-cluster API fallback: {' '.join(args)}"
    )


def remote_read(namespace: str, pod: str, path: str) -> str:
    script = f"test -r {shlex.quote(path)} && cat {shlex.quote(path)}"
    return run_cmd(["kubectl", "-n", namespace, "exec", pod, "--", "sh", "-c", script])


def detect_latest_remote_trace(namespace: str, pod: str) -> str:
    script = (
        "ls -1t /workspace/results/trace*.txt 2>/dev/null "
        "| head -n 1"
    )
    path = run_cmd(
        ["kubectl", "-n", namespace, "exec", pod, "--", "sh", "-c", script]
    ).strip()
    if not path:
        raise RuntimeError("No trace*.txt file found under /workspace/results")
    return path


def load_text(
    local_path: Optional[str],
    remote_path: Optional[str],
    namespace: str,
    driver_pod: str,
    required: bool,
) -> str:
    if local_path:
        return Path(local_path).read_text(encoding="utf-8")
    if remote_path:
        try:
            return remote_read(namespace, driver_pod, remote_path)
        except Exception:
            if required:
                raise
    return ""


def parse_duration(value: Optional[str]) -> Optional[float]:
    text = (value or "").strip()
    if not text or text == "-":
        return None
    total = 0.0
    matched = False
    for number, unit in re.findall(
        r"([0-9]+(?:\.[0-9]+)?)\s*(ms|us|ns|d|h|m|s)", text
    ):
        matched = True
        amount = float(number)
        multipliers = {
            "d": 86400.0,
            "h": 3600.0,
            "m": 60.0,
            "s": 1.0,
            "ms": 0.001,
            "us": 0.000001,
            "ns": 0.000000001,
        }
        total += amount * multipliers[unit]
    return total if matched else None


def parse_optional_int(value: Optional[str]) -> Optional[int]:
    text = (value or "").strip()
    if not text or text == "-":
        return None
    try:
        return int(text)
    except ValueError:
        return None


SIZE_UNITS = {
    "B": 1.0,
    "KB": 1_000.0,
    "MB": 1_000_000.0,
    "GB": 1_000_000_000.0,
    "TB": 1_000_000_000_000.0,
    "KIB": 1024.0,
    "MIB": 1024.0 ** 2,
    "GIB": 1024.0 ** 3,
    "TIB": 1024.0 ** 4,
}


def parse_size_bytes(value: Optional[str]) -> Optional[float]:
    """Parse a Nextflow trace size such as ``422.3 MB`` into bytes."""
    text = (value or "").strip()
    if not text or text == "-":
        return None
    match = re.match(r"^([0-9]*\.?[0-9]+)\s*([A-Za-z]*)$", text)
    if not match:
        return None
    factor = SIZE_UNITS.get((match.group(2) or "B").upper())
    if factor is None:
        return None
    return float(match.group(1)) * factor


def parse_cpu_percent(value: Optional[str]) -> Optional[float]:
    """Parse the Nextflow trace ``%cpu`` column."""
    text = (value or "").strip().rstrip("%").strip()
    if not text or text == "-":
        return None
    try:
        return float(text)
    except ValueError:
        return None


def trace_memory_bytes(
    tasks: Sequence[TaskRecord],
) -> Tuple[Optional[float], Optional[float]]:
    """Return time-weighted mean and peak concurrent trace peak RSS.

    Nextflow records peak RSS even for tasks whose pods finish between
    Prometheus scrapes. Each task contributes its peak RSS over its execution
    interval; this is deliberately an approximation and the emitted method
    text says so.
    """
    events: List[Tuple[float, float]] = []
    for task in tasks:
        if task.peak_rss_bytes is None or task.end is None:
            continue
        start_ts = (task.start or task.submit).timestamp()
        end_ts = max(task.end.timestamp(), start_ts + 0.001)
        events.append((start_ts, task.peak_rss_bytes))
        events.append((end_ts, -task.peak_rss_bytes))
    if not events:
        return None, None

    # Process end events before start events at identical timestamps so tasks
    # that merely touch at a boundary are not counted as concurrent.
    events.sort(key=lambda item: (item[0], item[1] > 0))
    current = 0.0
    peak = 0.0
    weighted = 0.0
    previous_ts = events[0][0]
    for timestamp, delta in events:
        if timestamp > previous_ts:
            weighted += current * (timestamp - previous_ts)
            previous_ts = timestamp
        current += delta
        peak = max(peak, current)
    span = events[-1][0] - events[0][0]
    average = weighted / span if span > 0 else peak
    return average, peak


def parse_trace_datetime(value: str, trace_tz: ZoneInfo) -> datetime:
    parsed = datetime.strptime(value.strip(), "%Y-%m-%d %H:%M:%S.%f")
    return parsed.replace(tzinfo=trace_tz)


def parse_trace(text: str, trace_tz: ZoneInfo) -> List[TaskRecord]:
    reader = csv.DictReader(io.StringIO(text), delimiter="\t")
    required = {"task_id", "hash", "native_id", "name", "status", "submit"}
    if not reader.fieldnames or not required.issubset(set(reader.fieldnames)):
        raise RuntimeError(
            "The Nextflow trace is missing required columns: "
            + ", ".join(sorted(required))
        )

    tasks: List[TaskRecord] = []
    for row in reader:
        submit_text = (row.get("submit") or "").strip()
        if not submit_text or submit_text == "-":
            continue
        duration = parse_duration(row.get("duration"))
        submit = parse_trace_datetime(submit_text, trace_tz)
        pod_name = (row.get("native_id") or "").strip()
        if not pod_name or pod_name == "-":
            pod_name = None
        task = TaskRecord(
            task_id=(row.get("task_id") or "").strip(),
            hash_value=(row.get("hash") or "").strip(),
            pod_name=pod_name,
            name=(row.get("name") or "").strip(),
            status=(row.get("status") or "UNKNOWN").strip().upper(),
            exit_code=parse_optional_int(row.get("exit")),
            submit=submit,
            duration_seconds=duration,
            realtime_seconds=parse_duration(row.get("realtime")),
            cpu_percent=parse_cpu_percent(row.get("%cpu")),
            peak_rss_bytes=parse_size_bytes(row.get("peak_rss")),
        )
        start_text = (row.get("start") or "").strip()
        if start_text and start_text != "-":
            task.start = parse_trace_datetime(start_text, trace_tz)
        complete_text = (row.get("complete") or "").strip()
        if complete_text and complete_text != "-":
            task.end = parse_trace_datetime(complete_text, trace_tz)
        elif duration is not None:
            task.end = submit + timedelta(seconds=duration)
        if (
            task.start is None
            and task.end is not None
            and task.realtime_seconds is not None
        ):
            task.start = task.end - timedelta(seconds=task.realtime_seconds)
        tasks.append(task)

    if not tasks:
        raise RuntimeError("The selected Nextflow trace contains no submitted tasks")
    return tasks


def parse_log_timestamp(line: str, year: int, log_tz: ZoneInfo) -> Optional[datetime]:
    match = LOG_TS_RE.match(line)
    if not match:
        return None
    month = MONTHS.get(match.group("month"))
    if month is None:
        return None
    clock = datetime.strptime(match.group("time"), "%H:%M:%S.%f")
    return datetime(
        year,
        month,
        int(match.group("day")),
        clock.hour,
        clock.minute,
        clock.second,
        clock.microsecond,
        tzinfo=log_tz,
    )


def extract_failure_reason(*logs: str) -> Optional[str]:
    merged = "\n".join(log for log in logs if log)
    error_match = re.search(r"(?m)^ERROR\s+~\s+(.+)$", merged)
    cause_match = re.search(r"(?m)^Caused by:\s*\n\s*(.+)$", merged)
    parts: List[str] = []
    if error_match:
        parts.append(error_match.group(1).strip())
    if cause_match:
        cause = cause_match.group(1).strip()
        if cause not in parts:
            parts.append(cause)
    return ": ".join(parts) if parts else None


def parse_log_metadata(
    debug_log: str,
    console_log: str,
    trace_year: int,
    log_tz: ZoneInfo,
) -> Dict[str, Any]:
    timestamps = [
        ts
        for ts in (
            parse_log_timestamp(line, trace_year, log_tz)
            for line in debug_log.splitlines()
        )
        if ts is not None
    ]
    session_match = SESSION_RE.search(debug_log)
    run_name_match = RUN_NAME_RE.search(debug_log)
    version_match = NEXTFLOW_VERSION_RE.search(debug_log)
    finished = "Execution complete" in debug_log
    terminal_failure = bool(
        re.search(r"(?m)^ERROR\s*~", console_log)
    ) or "Session aborted -- Cause" in debug_log
    return {
        "start": min(timestamps) if timestamps else None,
        "end": max(timestamps) if timestamps else None,
        "session_id": session_match.group(1) if session_match else None,
        "run_name": run_name_match.group(1) if run_name_match else None,
        "nextflow_version": version_match.group(1) if version_match else None,
        "finished": finished,
        "successful": finished and not terminal_failure,
        "failure_reason": extract_failure_reason(debug_log, console_log),
    }


def normalize_finished_tasks(tasks: List[TaskRecord], run_finished: bool) -> None:
    if not run_finished:
        return
    for task in tasks:
        if task.status in {"RUNNING", "SUBMITTED", "NEW", "PENDING"}:
            task.status = "ABORTED"


def derive_status(
    tasks: Sequence[TaskRecord],
    run_finished: bool,
    workflow_succeeded: bool = False,
) -> str:
    statuses = {task.status for task in tasks}
    if statuses & {"RUNNING", "SUBMITTED", "NEW", "PENDING"}:
        return "Running"
    if not run_finished:
        return "Running"
    if workflow_succeeded:
        if statuses & {"FAILED", "ERROR", "ABORTED"}:
            return "Succeeded with warnings"
        if statuses and statuses <= {"COMPLETED", "CACHED"}:
            return "Succeeded"
    if statuses & {"FAILED", "ERROR"}:
        return "Failed"
    if statuses and statuses <= {"COMPLETED", "CACHED"}:
        return "Succeeded"
    if "ABORTED" in statuses:
        return "Aborted"
    return "Unknown"


def validate_required_success(
    tasks: Sequence[TaskRecord],
    run_status: str,
    required: bool,
) -> None:
    """Enforce a clean, uncached run for strict publication profiles."""
    if not required:
        return
    non_completed_tasks = [
        task for task in tasks if task.status != "COMPLETED"
    ]
    if run_status != "Succeeded" or non_completed_tasks:
        raise RuntimeError(
            "Strict collection requires a clean uncached Succeeded run, but "
            f"the selected trace/logs resolve to {run_status} with "
            f"{len(non_completed_tasks)} non-COMPLETED task row(s)."
        )


def task_status_label(status: str) -> str:
    mapping = {
        "COMPLETED": "Succeeded",
        "CACHED": "Cached",
        "FAILED": "Failed",
        "ERROR": "Failed",
        "ABORTED": "Aborted",
        "RUNNING": "Running",
        "SUBMITTED": "Submitted",
        "PENDING": "Pending",
    }
    return mapping.get(status.upper(), status.title())


def seconds_between(start: datetime, end: datetime) -> int:
    return max(1, int(math.ceil((end - start).total_seconds())))


def resource_accounting_window(
    tasks: Sequence[TaskRecord],
    run_start: datetime,
    run_end: datetime,
    include_cached_origin_metrics: bool,
) -> Tuple[datetime, datetime]:
    if not include_cached_origin_metrics:
        return run_start, run_end
    trace_start = min(task.submit for task in tasks)
    trace_end = max((task.end or run_end) for task in tasks)
    return min(run_start, trace_start), max(run_end, trace_end)


def http_get_json(
    url: str,
    params: Optional[Dict[str, str]] = None,
    headers: Optional[Dict[str, str]] = None,
) -> Dict[str, Any]:
    if params:
        url = f"{url}?{urllib.parse.urlencode(params)}"
    request_headers = {
        "Accept": "application/json",
        "User-Agent": "geoflow-vivo-metadata-collector/1.0",
    }
    request_headers.update(headers or {})
    request = urllib.request.Request(url, headers=request_headers)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            f"HTTP {exc.code} returned by {url}: {detail}"
        ) from exc


def api_datetime(value: datetime) -> str:
    return (
        value.astimezone(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def electricity_maps_points(payload: Dict[str, Any]) -> List[Dict[str, Any]]:
    for key in ("data", "history"):
        value = payload.get(key)
        if isinstance(value, list):
            return [item for item in value if isinstance(item, dict)]
    if "value" in payload or "carbonIntensity" in payload:
        return [payload]
    return []


def parse_api_datetime(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def resolve_co2map_carbon_intensity(
    args: argparse.Namespace,
    start: datetime,
    end: datetime,
) -> CarbonIntensityInfo:
    status = args.co2map_data_status
    endpoint = (
        f"{args.co2map_api_url.rstrip('/')}/"
        f"ConsumptionIntensity{status.title()}/"
    )
    start_utc = start.astimezone(timezone.utc)
    end_utc = end.astimezone(timezone.utc)
    query_end = end_utc + timedelta(days=1)
    payload = http_get_json(
        endpoint,
        {
            "state": args.co2map_state,
            "country": args.co2map_country,
            "start": start_utc.date().isoformat(),
            "end": query_end.date().isoformat(),
        },
    )
    series = next(
        (
            value
            for key, value in payload.items()
            if "Consumption-based Intensity" in key
            and isinstance(value, list)
        ),
        [],
    )
    values: List[float] = []
    selected_times: List[datetime] = []
    for item in series:
        if not isinstance(item, list) or len(item) < 2:
            continue
        try:
            point_start = parse_api_datetime(str(item[0]))
            value = float(item[1])
        except (TypeError, ValueError):
            continue
        point_end = point_start + timedelta(hours=1)
        if (
            point_start < end_utc
            and point_end > start_utc
            and math.isfinite(value)
        ):
            selected_times.append(point_start)
            values.append(value)
    if not values:
        raise RuntimeError(
            "CO2Map.de returned no finite consumption-intensity values "
            f"overlapping {api_datetime(start_utc)} to "
            f"{api_datetime(end_utc)}. Preliminary data can be delayed."
        )

    average_g_per_kwh = sum(values) / len(values)
    selected_start = min(selected_times)
    selected_end = max(selected_times) + timedelta(hours=1)
    return CarbonIntensityInfo(
        kg_per_kwh=average_g_per_kwh / 1000.0,
        source=(
            "CO2Map.de "
            f"{status} consumption-based direct CO2 intensity "
            "(model-based)"
        ),
        source_uri=endpoint,
        zone=args.co2map_state,
        point_count=len(values),
        includes_estimates=True,
        start=api_datetime(selected_start),
        end=api_datetime(selected_end),
        emissions_basis="direct CO2",
        temporal_granularity="hourly",
    )


def resolve_electricity_maps_latest_intensity(
    args: argparse.Namespace,
    token: str,
) -> CarbonIntensityInfo:
    payload = http_get_json(
        args.electricity_maps_latest_api_url,
        {"zone": args.electricity_maps_zone},
        {"auth-token": token},
    )
    raw_value = payload.get("carbonIntensity", payload.get("value"))
    try:
        value = float(raw_value)
    except (TypeError, ValueError) as exc:
        raise RuntimeError(
            "Electricity Maps latest endpoint returned no finite "
            f"carbon-intensity value for zone {args.electricity_maps_zone}."
        ) from exc
    if not math.isfinite(value):
        raise RuntimeError(
            "Electricity Maps latest endpoint returned no finite "
            f"carbon-intensity value for zone {args.electricity_maps_zone}."
        )

    point_start: Optional[datetime] = None
    raw_datetime = payload.get("datetime")
    if raw_datetime:
        try:
            point_start = parse_api_datetime(str(raw_datetime))
        except ValueError:
            point_start = None

    granularity = str(payload.get("temporalGranularity") or "latest available")
    duration_by_granularity = {
        "hourly": timedelta(hours=1),
        "30_minutes": timedelta(minutes=30),
        "15_minutes": timedelta(minutes=15),
        "5_minutes": timedelta(minutes=5),
    }
    point_end = (
        point_start + duration_by_granularity[granularity]
        if point_start and granularity in duration_by_granularity
        else None
    )
    factor_type = str(payload.get("emissionFactorType") or "lifecycle")
    emissions_basis = (
        "lifecycle CO2e" if factor_type == "lifecycle" else f"{factor_type} CO2e"
    )
    return CarbonIntensityInfo(
        kg_per_kwh=value / 1000.0,
        source=(
            "Electricity Maps latest available flow-traced carbon intensity "
            "(collection-time proxy)"
        ),
        source_uri=args.electricity_maps_latest_api_url,
        zone=str(payload.get("zone") or args.electricity_maps_zone),
        point_count=1,
        includes_estimates=bool(payload.get("isEstimated")),
        start=api_datetime(point_start) if point_start else None,
        end=api_datetime(point_end) if point_end else None,
        emissions_basis=emissions_basis,
        temporal_granularity=granularity.replace("_", " "),
        method_note=(
            "The value is the latest value available from the free-tier "
            "endpoint when metadata was collected. It is used as a proxy "
            "and is not guaranteed to represent the exact workflow "
            "execution interval."
        ),
    )


def resolve_carbon_intensity(
    args: argparse.Namespace,
    start: datetime,
    end: datetime,
) -> CarbonIntensityInfo:
    if args.carbon_intensity_source == "fixed":
        return CarbonIntensityInfo(
            kg_per_kwh=args.carbon_intensity,
            source="Fixed configured emissions factor",
        )

    if args.carbon_intensity_source == "co2map":
        return resolve_co2map_carbon_intensity(args, start, end)

    token = os.environ.get(args.electricity_maps_api_token_env)
    if not token:
        raise RuntimeError(
            "Electricity Maps was selected, but environment variable "
            f"{args.electricity_maps_api_token_env} is empty."
        )

    if args.carbon_intensity_source == "electricity-maps-latest":
        return resolve_electricity_maps_latest_intensity(args, token)

    # 15-minute values where the account and the zone have them, hourly values otherwise.
    errors: List[str] = []
    for granularity, step_seconds in (("15_minutes", 900), ("hourly", 3600)):
        try:
            return _electricity_maps_range_intensity(args, token, start, end, granularity, step_seconds)
        except (RuntimeError, ValueError, KeyError, TypeError, OSError) as exc:
            errors.append(f"{granularity}: {exc}")
    raise RuntimeError("Electricity Maps has no carbon intensity for the run's time (" + "; ".join(errors) + ")")


def _electricity_maps_range_intensity(
    args: argparse.Namespace,
    token: str,
    start: datetime,
    end: datetime,
    granularity: str,
    step_seconds: int,
) -> CarbonIntensityInfo:
    start_epoch = int(start.astimezone(timezone.utc).timestamp())
    end_epoch = int(end.astimezone(timezone.utc).timestamp())
    query_start_epoch = (start_epoch // step_seconds) * step_seconds
    query_end_epoch = (
        ((end_epoch + step_seconds - 1) // step_seconds) * step_seconds
    )
    if query_end_epoch <= query_start_epoch:
        query_end_epoch = query_start_epoch + step_seconds
    query_start = datetime.fromtimestamp(query_start_epoch, timezone.utc)
    query_end = datetime.fromtimestamp(query_end_epoch, timezone.utc)

    params = {
        "zone": args.electricity_maps_zone,
        "start": api_datetime(query_start),
        "end": api_datetime(query_end),
        "emissionFactorType": "lifecycle",
        "temporalGranularity": granularity,
        "flowTraced": "true",
        "disableEstimations": (
            "true"
            if args.electricity_maps_disable_estimations
            else "false"
        ),
    }
    payload = http_get_json(
        args.electricity_maps_api_url,
        params,
        {"auth-token": token},
    )
    returned = payload.get("temporalGranularity")
    if returned is not None and returned != granularity:
        raise RuntimeError(f"Electricity Maps returned {returned} data instead of {granularity}")
    points = electricity_maps_points(payload)
    values: List[float] = []
    includes_estimates = False
    for point in points:
        raw_value = point.get("value", point.get("carbonIntensity"))
        try:
            value = float(raw_value)
        except (TypeError, ValueError):
            continue
        if math.isfinite(value):
            values.append(value)
            includes_estimates = (
                includes_estimates or bool(point.get("isEstimated"))
            )
    if not values:
        raise RuntimeError(
            "Electricity Maps returned no finite carbon-intensity values "
            f"for zone {args.electricity_maps_zone} between "
            f"{api_datetime(query_start)} and {api_datetime(query_end)}."
        )
    if args.electricity_maps_disable_estimations and includes_estimates:
        raise RuntimeError(
            "Electricity Maps returned at least one estimated carbon-intensity "
            "point even though --electricity-maps-disable-estimations was set."
        )

    label = "15 minutes" if granularity == "15_minutes" else "hourly"
    average_g_per_kwh = sum(values) / len(values)
    return CarbonIntensityInfo(
        kg_per_kwh=average_g_per_kwh / 1000.0,
        source=(
            f"Electricity Maps {'15-minute' if granularity == '15_minutes' else 'hourly'} history "
            "(flow-traced lifecycle carbon intensity)"
        ),
        source_uri=args.electricity_maps_api_url,
        zone=args.electricity_maps_zone,
        point_count=len(values),
        includes_estimates=includes_estimates,
        start=api_datetime(query_start),
        end=api_datetime(query_end),
        emissions_basis="lifecycle CO2e",
        temporal_granularity=label,
    )


def prom_query(prom_url: str, query: str) -> Any:
    data = http_get_json(f"{prom_url.rstrip('/')}/api/v1/query", {"query": query})
    if data.get("status") != "success":
        raise RuntimeError(f"Prometheus query failed:\n{query}\n{data}")
    return data["data"]["result"]


def prom_query_range(
    prom_url: str,
    query: str,
    start: datetime,
    end: datetime,
    step_seconds: int,
) -> Any:
    params = {
        "query": query,
        "start": str(start.timestamp()),
        "end": str(end.timestamp()),
        "step": f"{step_seconds}s",
    }
    data = http_get_json(f"{prom_url.rstrip('/')}/api/v1/query_range", params)
    if data.get("status") != "success":
        raise RuntimeError(f"Prometheus range query failed:\n{query}\n{data}")
    return data["data"]["result"]


def first_finite_value(result: Any) -> Optional[float]:
    if not result:
        return None
    try:
        if (
            isinstance(result, list)
            and len(result) == 2
            and not isinstance(result[0], dict)
        ):
            value = float(result[1])
        else:
            value = float(result[0]["value"][1])
    except (KeyError, IndexError, TypeError, ValueError):
        return None
    return value if math.isfinite(value) else None


def prometheus_metric_names(prom_url: str) -> List[str]:
    data = http_get_json(f"{prom_url.rstrip('/')}/api/v1/label/__name__/values")
    if data.get("status") != "success":
        return []
    return [str(name) for name in data.get("data", [])]


def ensure_prometheus_reachable(prom_url: str) -> None:
    try:
        result = prom_query(prom_url, "1")
    except Exception as exc:
        raise RuntimeError(
            f"Prometheus is not reachable at {prom_url}. Start the port-forward first."
        ) from exc
    if first_finite_value(result) != 1.0:
        raise RuntimeError(f"Prometheus at {prom_url} returned an unexpected response")


def find_energy_metric(metric_names: Sequence[str]) -> Optional[str]:
    preferred = [
        "kepler_container_joules_total",
        "kepler_pod_joules_total",
        "kepler_container_package_joules_total",
        "kepler_pod_package_joules_total",
    ]
    for metric in preferred:
        if metric in metric_names:
            return metric
    for metric in metric_names:
        low = metric.lower()
        if "kepler" in low and "joule" in low:
            return metric
    return None


def range_expr(selector: str, start: datetime, end: datetime) -> str:
    return f"{selector}[{seconds_between(start, end)}s] @ {int(end.timestamp())}"


def cpu_selectors(namespace: str, pod_name: str) -> List[str]:
    return [
        (
            "container_cpu_usage_seconds_total"
            f'{{namespace="{namespace}",pod="{pod_name}",'
            'container!="",container!="POD",image!=""}'
        ),
        (
            "container_cpu_usage_seconds_total"
            f'{{namespace="{namespace}",pod="{pod_name}",'
            'container!="",container!="POD"}'
        ),
        (
            "container_cpu_usage_seconds_total"
            f'{{pod="{pod_name}",container!="",container!="POD",image!=""}}'
        ),
    ]


def query_cpu_for_pod(
    prom_url: str,
    namespace: str,
    pod_name: str,
    start: datetime,
    end: datetime,
) -> Tuple[Optional[float], Optional[str], Optional[str]]:
    zero_result: Tuple[Optional[float], Optional[str], Optional[str]] = (
        None,
        None,
        None,
    )
    for selector in cpu_selectors(namespace, pod_name):
        query = f"sum(increase({range_expr(selector, start, end)}))"
        try:
            value = first_finite_value(prom_query(prom_url, query))
        except Exception:
            continue
        if value is not None and value > 0:
            return value, query, "increase"
        if value == 0 and zero_result[0] is None:
            zero_result = (value, query, "increase")

    for selector in cpu_selectors(namespace, pod_name):
        query = f"sum(max_over_time({range_expr(selector, start, end)}))"
        try:
            value = first_finite_value(prom_query(prom_url, query))
        except Exception:
            continue
        if value is not None and value > 0:
            return value, query, "counter-maximum fallback"
    return zero_result


def energy_selectors(metric: str, namespace: str, pod_name: str) -> List[str]:
    return [
        f'{metric}{{namespace="{namespace}",pod_name="{pod_name}"}}',
        f'{metric}{{namespace="{namespace}",pod="{pod_name}"}}',
        f'{metric}{{container_namespace="{namespace}",pod_name="{pod_name}"}}',
        f'{metric}{{pod_namespace="{namespace}",pod_name="{pod_name}"}}',
        f'{metric}{{pod_name="{pod_name}"}}',
        f'{metric}{{pod="{pod_name}"}}',
    ]


def query_energy_for_pod(
    prom_url: str,
    metric: Optional[str],
    namespace: str,
    pod_name: str,
    start: datetime,
    end: datetime,
) -> Tuple[Optional[float], Optional[str], Optional[str], bool]:
    if not metric:
        return None, None, None, False

    selectors = energy_selectors(metric, namespace, pod_name)
    zero_result: Tuple[Optional[float], Optional[str], Optional[str], bool] = (
        None,
        None,
        None,
        False,
    )
    for selector in selectors:
        query = f"sum(increase({range_expr(selector, start, end)}))"
        try:
            value = first_finite_value(prom_query(prom_url, query))
        except Exception:
            continue
        if value is not None and value > 0:
            return value, query, "counter increase", False
        if value == 0 and zero_result[0] is None:
            zero_result = (value, query, "counter increase", False)

    for selector in selectors:
        ranged = range_expr(selector, start, end)
        query = f"sum(max_over_time({ranged}) - min_over_time({ranged}))"
        try:
            value = first_finite_value(prom_query(prom_url, query))
        except Exception:
            continue
        if value is not None and value > 0:
            return value, query, "observed counter range fallback", True

    for selector in selectors:
        query = f"sum(max_over_time({range_expr(selector, start, end)}))"
        try:
            value = first_finite_value(prom_query(prom_url, query))
        except Exception:
            continue
        if value is not None and value > 0:
            return value, query, "counter maximum estimate", True
    return zero_result


def memory_selectors(namespace: str, pod_name: str) -> List[str]:
    return [
        (
            "container_memory_working_set_bytes"
            f'{{namespace="{namespace}",pod="{pod_name}",'
            'container!="",container!="POD",image!=""}'
        ),
        (
            "container_memory_working_set_bytes"
            f'{{namespace="{namespace}",pod="{pod_name}",'
            'container!="",container!="POD"}'
        ),
        (
            "container_memory_working_set_bytes"
            f'{{pod="{pod_name}",container!="",container!="POD",image!=""}}'
        ),
    ]


def query_memory_for_pod(
    prom_url: str,
    namespace: str,
    pod_name: str,
    start: datetime,
    end: datetime,
    step_seconds: int,
) -> Tuple[Dict[int, float], Optional[str]]:
    for selector in memory_selectors(namespace, pod_name):
        query = f"sum({selector})"
        try:
            result = prom_query_range(
                prom_url, query, start, end, step_seconds
            )
        except Exception:
            continue
        if not result:
            continue
        values = result[0].get("values", [])
        series: Dict[int, float] = {}
        for timestamp, raw_value in values:
            try:
                value = float(raw_value)
            except (TypeError, ValueError):
                continue
            if math.isfinite(value):
                series[int(float(timestamp))] = value
        if series:
            return series, query
    return {}, None


def candidate_probe_times(
    task: TaskRecord,
    run_start: datetime,
    run_end: datetime,
) -> List[datetime]:
    task_end = task.end or run_end
    candidates = [
        task.submit + (task_end - task.submit) / 2,
        max(task.submit, task_end - timedelta(seconds=5)),
        task.submit + timedelta(seconds=30),
        run_end,
    ]
    result: List[datetime] = []
    for candidate in candidates:
        bounded = min(max(candidate, run_start), run_end)
        if bounded not in result:
            result.append(bounded)
    return result


def query_pod_info(
    prom_url: str,
    namespace: str,
    task: TaskRecord,
    run_start: datetime,
    run_end: datetime,
) -> Tuple[Optional[str], List[str]]:
    if not task.pod_name:
        return None, []
    node_name: Optional[str] = None
    images: List[str] = []
    for timestamp in candidate_probe_times(task, run_start, run_end):
        at_expr = f" @ {int(timestamp.timestamp())}"
        info_queries = [
            (
                "kube_pod_info"
                f'{{namespace="{namespace}",pod="{task.pod_name}"}}{at_expr}'
            ),
            f'kube_pod_info{{pod="{task.pod_name}"}}{at_expr}',
        ]
        for query in info_queries:
            try:
                result = prom_query(prom_url, query)
            except Exception:
                continue
            if result:
                node_name = result[0].get("metric", {}).get("node")
                break
        if node_name:
            break

    for timestamp in candidate_probe_times(task, run_start, run_end):
        at_expr = f" @ {int(timestamp.timestamp())}"
        image_queries = [
            (
                "kube_pod_container_info"
                f'{{namespace="{namespace}",pod="{task.pod_name}"}}{at_expr}'
            ),
            f'kube_pod_container_info{{pod="{task.pod_name}"}}{at_expr}',
        ]
        for query in image_queries:
            try:
                result = prom_query(prom_url, query)
            except Exception:
                continue
            for row in result:
                image = row.get("metric", {}).get("image")
                if image and image not in images:
                    images.append(image)
            if images:
                break
        if images:
            break
    return node_name, images


def unique(values: Iterable[Optional[str]]) -> List[str]:
    result: List[str] = []
    for value in values:
        if value and value not in result:
            result.append(value)
    return result


def select_container_images(
    declared: Sequence[str],
    observed: Sequence[str],
    code_fallback: Sequence[str],
) -> List[str]:
    """Merge declared and observed images; use source scanning only as fallback.

    Completed Nextflow task pods are commonly deleted before collection, so
    Kubernetes/Prometheus discovery alone can omit scientifically important
    containers. Explicit digest-pinned declarations are therefore retained
    alongside observed image identities. Source scanning remains a last resort
    because a repository can contain inactive or historical profiles.
    """
    merged = unique([*declared, *observed])
    return merged if merged else unique(code_fallback)


def collect_pod_metrics(
    args: argparse.Namespace,
    tasks: Sequence[TaskRecord],
    metric_start: datetime,
    metric_end: datetime,
    energy_metric: Optional[str],
) -> Dict[str, PodMetrics]:
    task_by_pod = {
        task.pod_name: task
        for task in tasks
        if task.pod_name is not None
        and (
            task.status != "CACHED"
            or args.include_cached_origin_metrics
        )
    }
    result: Dict[str, PodMetrics] = {}
    for index, (pod_name, task) in enumerate(task_by_pod.items(), start=1):
        print(f"Collecting Prometheus metrics for pod {index}/{len(task_by_pod)}: {pod_name}")
        cpu_value, cpu_query, cpu_method = query_cpu_for_pod(
            args.prom_url,
            args.namespace,
            pod_name,
            metric_start,
            metric_end,
        )
        energy_value, energy_query, energy_method, energy_estimated = (
            query_energy_for_pod(
                args.prom_url,
                energy_metric,
                args.namespace,
                pod_name,
                metric_start,
                metric_end,
            )
        )
        memory_series, memory_query = query_memory_for_pod(
            args.prom_url,
            args.namespace,
            pod_name,
            metric_start,
            metric_end,
            args.memory_step_seconds,
        )
        node_name, images = query_pod_info(
            args.prom_url,
            args.namespace,
            task,
            metric_start,
            metric_end,
        )
        result[pod_name] = PodMetrics(
            pod_name=pod_name,
            cpu_seconds=cpu_value,
            cpu_query=cpu_query,
            cpu_method=cpu_method,
            energy_joules=energy_value,
            energy_query=energy_query,
            energy_method=energy_method,
            energy_estimated=energy_estimated,
            memory_series=memory_series,
            memory_query=memory_query,
            node_name=node_name,
            images=images,
        )
    return result


def aggregate_memory(
    metrics: Iterable[PodMetrics],
    start: datetime,
    end: datetime,
) -> Tuple[Optional[float], Optional[float]]:
    start_epoch = int(start.timestamp())
    end_epoch = int(end.timestamp())
    totals: Dict[int, float] = {}
    for pod_metrics in metrics:
        for timestamp, value in pod_metrics.memory_series.items():
            if start_epoch <= timestamp <= end_epoch:
                totals[timestamp] = totals.get(timestamp, 0.0) + value
    if not totals:
        return None, None
    values = list(totals.values())
    return sum(values) / len(values), max(values)


def bytes_to_gb(value: Optional[float]) -> Optional[float]:
    return value / 1_000_000_000.0 if value is not None else None


def joules_to_kwh(value: Optional[float]) -> Optional[float]:
    return value / 3_600_000.0 if value is not None else None


def canonical_task_name(task_name: str) -> str:
    """Remove Nextflow's trailing task tag while preserving the process name."""
    return re.sub(r"\s+\([^()]*\)$", "", task_name).strip()


def classify_stage(task_name: str) -> Tuple[str, str]:
    if task_name.startswith("calc_indices:"):
        return "spectral-index-calculation", "Spectral index calculation"
    if task_name.startswith("explode_base_files:"):
        return "base-band-extraction", "Base-band extraction"
    if task_name.startswith("build_vrt_stack:"):
        return "vrt-stack-construction", "VRT stack construction"
    base_name = canonical_task_name(task_name)
    return slugify(base_name), stage_label(base_name)


def stage_label(base_name: str, depth: int = 1) -> str:
    """Name a stage by the last `depth` segments of its qualified process name.

    Nextflow qualifies a process with every enclosing workflow, so the full
    name reads "NFCORE_RANGELAND:RANGELAND:HIGHER_LEVEL:FORCE_MOSAIC". Only the
    final segment names the step; the prefix repeats on every stage of the run.
    The slug keeps the full path, so shortening the label does not change any
    URI. `group_tasks` raises `depth` for the few stages whose short names would
    otherwise collide.
    """
    segments = [s for s in base_name.split(":") if s]
    if not segments:
        return "Workflow process"
    label = " / ".join(segments[-depth:]).replace("_", " ")
    return label[:1].upper() + label[1:]


def stage_run_label(label: str, run_start: datetime) -> str:
    """Name one execution of a stage after the stage and the start of its run.

    "FORCE MOSAIC" is the stage of the workflow; "FORCE MOSAIC · run
    2026-10-02 21:04" is that stage in one run. The time is the run's start in
    Europe/Berlin, as in the run title, so the name never changes and is unique
    per run.
    """
    started = run_start.astimezone(BERLIN_TZ).strftime("%Y-%m-%d %H:%M")
    return f"{label} \N{MIDDLE DOT} run {started}"


def workflow_stage_uri(base_uri: str, workflow_uri: str, stage_slug: str) -> str:
    """URI of a stage of a workflow: <base>stage/<workflow>/<stage>."""
    workflow_slug = slugify(re.split(r"[/#]", workflow_uri.rstrip("/#"))[-1])
    return f"{base_uri.rstrip('/')}/stage/{workflow_slug}/{stage_slug}"


def workflow_stage_predicates(
    label: str, workflow_uri: str, run_uri: str, execution_uri: str
) -> List[Tuple[str, str]]:
    """The stage of the workflow that one stage execution belongs to.

    The stage record is shared by all runs of the workflow; every run adds its
    own execution and itself to it.
    """
    return [
        ("rdf:type", "rm:WorkflowStage"),
        ("rdf:type", "vivo:InformationResource"),
        ("rdfs:label", ttl_label(label)),
        ("dcterms:title", ttl_label(label)),
        ("rm:stageOfWorkflow", ttl_uri(workflow_uri)),
        ("rm:hasStageExecution", ttl_uri(execution_uri)),
        ("rm:stageIncludedInRun", ttl_uri(run_uri)),
    ]


def lengthen_colliding_labels(groups: Iterable[Dict[str, Any]]) -> None:
    """Re-label stages whose short names are not unique within the run."""
    groups = list(groups)
    for _ in range(8):
        seen: Dict[str, List[Dict[str, Any]]] = {}
        for group in groups:
            seen.setdefault(group["label"], []).append(group)
        clashing = [
            g
            for sharers in seen.values()
            if len(sharers) > 1
            for g in sharers
            if g.get("base_name")
        ]
        if not clashing:
            return
        progressed = False
        for group in clashing:
            depth = len(group["label"].split(" / ")) + 1
            longer = stage_label(group["base_name"], depth)
            if longer != group["label"]:
                group["label"] = longer
                progressed = True
        if not progressed:
            return


def group_tasks(tasks: Sequence[TaskRecord]) -> List[Dict[str, Any]]:
    groups: Dict[str, Dict[str, Any]] = {}
    for task in tasks:
        slug, label = classify_stage(task.name)
        base_name = canonical_task_name(task.name)
        group = groups.setdefault(
            slug,
            {
                "slug": slug,
                "label": label,
                "tasks": [],
                "base_name": base_name if ":" in base_name else None,
            },
        )
        group["tasks"].append(task)
    lengthen_colliding_labels(groups.values())
    order = [
        "spectral-index-calculation",
        "base-band-extraction",
        "vrt-stack-construction",
    ]
    return sorted(
        groups.values(),
        key=lambda group: (
            order.index(group["slug"]) if group["slug"] in order else len(order),
            group["slug"],
        ),
    )


def summarize_metrics(
    pod_names: Sequence[str],
    pod_metrics: Dict[str, PodMetrics],
    start: datetime,
    end: datetime,
    carbon_intensity: float,
    tasks: Optional[Sequence[TaskRecord]] = None,
) -> Dict[str, Any]:
    selected = [
        pod_metrics[pod_name]
        for pod_name in unique(pod_names)
        if pod_name in pod_metrics
    ]
    cpu_values = [
        metrics.cpu_seconds
        for metrics in selected
        if metrics.cpu_seconds is not None
    ]
    energy_values = [
        metrics.energy_joules
        for metrics in selected
        if metrics.energy_joules is not None
    ]
    memory_avg, memory_peak = aggregate_memory(selected, start, end)
    cpu_total = sum(cpu_values) if cpu_values else None
    energy_joules = sum(energy_values) if energy_values else None
    energy_kwh = joules_to_kwh(energy_joules)
    energy_estimated = any(metrics.energy_estimated for metrics in selected)
    cpu_fallbacks = sum(
        1
        for metrics in selected
        if metrics.cpu_method and "fallback" in metrics.cpu_method
    )
    trace_tasks = list(tasks or [])
    trace_cpu_values = [
        task.trace_cpu_seconds
        for task in trace_tasks
        if task.trace_cpu_seconds is not None
    ]
    trace_cpu_total = sum(trace_cpu_values) if trace_cpu_values else None
    cpu_source = "trace" if trace_cpu_total is not None else "prometheus"

    trace_memory_avg, trace_memory_peak = trace_memory_bytes(trace_tasks)
    memory_source = (
        "trace" if trace_memory_peak is not None else "prometheus"
    )
    if trace_memory_peak is not None:
        memory_avg = trace_memory_avg
        memory_peak = trace_memory_peak
    return {
        "cpu_seconds": (
            trace_cpu_total if trace_cpu_total is not None else cpu_total
        ),
        "cpu_source": cpu_source,
        "cpu_trace_seconds": trace_cpu_total,
        "cpu_trace_task_count": len(trace_cpu_values),
        "cpu_task_count": len(trace_tasks),
        "cpu_prometheus_seconds": cpu_total,
        "cpu_pod_count": len(cpu_values),
        "cpu_fallback_count": cpu_fallbacks,
        "memory_avg_gb": bytes_to_gb(memory_avg),
        "memory_peak_gb": bytes_to_gb(memory_peak),
        "memory_pod_count": sum(bool(metrics.memory_series) for metrics in selected),
        "memory_source": memory_source,
        "memory_task_count": sum(
            task.peak_rss_bytes is not None for task in trace_tasks
        ),
        "energy_kwh": energy_kwh,
        "energy_pod_count": len(energy_values),
        "energy_estimated": energy_estimated,
        "carbon_kg": (
            energy_kwh * carbon_intensity
            if energy_kwh is not None
            else None
        ),
    }


def metric_methods(
    summary: Dict[str, Any],
    pod_count: int,
    carbon_info: CarbonIntensityInfo,
    cached_origin_metrics: bool = False,
    cluster_uri: Optional[str] = None,
) -> Dict[str, str]:
    if summary.get("cpu_source") == "trace":
        cpu_method = (
            "CPU time is the sum of realtime multiplied by %cpu from the "
            f"Nextflow trace for {summary['cpu_trace_task_count']} of "
            f"{summary['cpu_task_count']} task(s). This covers short-lived "
            "pods that may finish between Prometheus scrapes."
        )
        prometheus_seconds = summary.get("cpu_prometheus_seconds")
        if prometheus_seconds is not None:
            cpu_method += (
                " For comparison, Prometheus "
                "container_cpu_usage_seconds_total measured "
                f"{prometheus_seconds:.6g} seconds across "
                f"{summary['cpu_pod_count']} of {pod_count} pod(s)."
            )
    else:
        cpu_method = (
            "CPU time is the sum of Prometheus "
            "container_cpu_usage_seconds_total counter increases"
            f" for {summary['cpu_pod_count']} of {pod_count} pod(s)."
        )
        if summary["cpu_fallback_count"]:
            cpu_method += (
                f" A counter-maximum fallback was used for "
                f"{summary['cpu_fallback_count']} short-lived pod(s)."
            )
    if summary.get("memory_source") == "trace":
        memory_method = (
            "Memory is approximated from peak_rss in the Nextflow trace for "
            f"{summary['memory_task_count']} task(s). Each task contributes "
            "its peak resident memory over its execution interval; the peak "
            "is the maximum concurrent sum and the average is time-weighted."
        )
    else:
        memory_method = (
            "Memory is derived from Prometheus "
            "container_memory_working_set_bytes. Values are summed across "
            "concurrent workflow pods at each sample; the reported average "
            "and peak are calculated from that aggregate time series."
        )
    energy_method = (
        f"Energy is the sum of per-pod Kepler measurements for "
        f"{summary['energy_pod_count']} of {pod_count} pod(s)."
    )
    if summary["energy_estimated"]:
        energy_method += (
            " At least one short-lived pod required a counter-range or "
            "counter-maximum estimate because a reliable counter increase "
            "was unavailable."
        )
    carbon_method = (
        "Carbon emissions are calculated using the emissions factor method: "
        "energy consumption (kWh) multiplied by "
        f"{carbon_info.kg_per_kwh} kg/kWh "
        f"({carbon_info.emissions_basis}) from "
        f"{carbon_info.source}."
    )
    if carbon_info.point_count:
        if carbon_info.method_note:
            carbon_method += f" {carbon_info.method_note}"
        else:
            carbon_method += (
                f" The factor is the arithmetic mean of "
                f"{carbon_info.point_count} uniformly spaced carbon-intensity "
                "measurements over the resource-accounting window."
            )
    if cached_origin_metrics:
        cache_note = (
            " Metrics include the original Kubernetes pods that produced "
            "outputs reused from the Nextflow cache."
        )
        cpu_method += cache_note
        memory_method += cache_note
        energy_method += cache_note
    if summary["energy_pod_count"] and cluster_uri == DEFAULT_CLUSTER_URI:
        energy_method += FONDA_KEPLER_IDLE_NOTE
    return {
        "cpu": cpu_method,
        "memory": memory_method,
        "energy": energy_method,
        "carbon": carbon_method,
    }


def parse_k8s_bytes(quantity: str) -> Optional[float]:
    match = re.fullmatch(
        r"([0-9]+(?:\.[0-9]+)?)([A-Za-z]+)?", (quantity or "").strip()
    )
    if not match:
        return None
    value = float(match.group(1))
    suffix = match.group(2) or ""
    multipliers = {
        "": 1.0,
        "Ki": 1024.0,
        "Mi": 1024.0 ** 2,
        "Gi": 1024.0 ** 3,
        "Ti": 1024.0 ** 4,
        "K": 1000.0,
        "M": 1000.0 ** 2,
        "G": 1000.0 ** 3,
        "T": 1000.0 ** 4,
    }
    multiplier = multipliers.get(suffix)
    return value * multiplier if multiplier is not None else None


def prometheus_label_value(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def prometheus_number_text(value: Optional[float]) -> Optional[str]:
    if value is None:
        return None
    if value.is_integer():
        return str(int(value))
    return format(value, ".15g")


def collect_prometheus_node_info(
    prom_url: str, node_name: str
) -> Dict[str, Any]:
    """Read kube-state-metrics node facts without cluster-scoped RBAC."""
    node = prometheus_label_value(node_name)
    try:
        info_result = prom_query(
            prom_url, f'kube_node_info{{node="{node}"}}'
        )
    except Exception:
        info_result = []
    metric = (
        info_result[0].get("metric", {})
        if isinstance(info_result, list) and info_result
        else {}
    )
    label_map = {
        "architecture": "architecture",
        "kernel_version": "kernelVersion",
        "kubelet_version": "kubeletVersion",
        "os_image": "osImage",
    }
    node_info = {
        target: metric[source]
        for source, target in label_map.items()
        if metric.get(source)
    }
    if not node_info.get("architecture"):
        try:
            uname_result = prom_query(
                prom_url, f'node_uname_info{{nodename="{node}"}}'
            )
        except Exception:
            uname_result = []
        uname_metric = (
            uname_result[0].get("metric", {})
            if isinstance(uname_result, list) and uname_result
            else {}
        )
        machine_to_kubernetes_arch = {
            "x86_64": "amd64",
            "aarch64": "arm64",
            "armv7l": "arm",
        }
        machine = uname_metric.get("machine")
        if machine:
            node_info["architecture"] = machine_to_kubernetes_arch.get(
                machine, machine
            )
        if uname_metric.get("release") and not node_info.get("kernelVersion"):
            node_info["kernelVersion"] = uname_metric["release"]

    allocatable: Dict[str, str] = {}
    for resource in ("cpu", "memory"):
        try:
            result = prom_query(
                prom_url,
                "kube_node_status_allocatable"
                f'{{node="{node}",resource="{resource}"}}',
            )
        except Exception:
            result = []
        value = prometheus_number_text(first_finite_value(result))
        if value is not None:
            allocatable[resource] = value

    return {
        "name": node_name,
        "node_info": node_info,
        "allocatable": allocatable,
        "labels": {},
        "metadata_sources": ["prometheus"],
    }


def merge_node_info(
    primary: Dict[str, Any], fallback: Dict[str, Any]
) -> Dict[str, Any]:
    merged = {
        "name": primary.get("name") or fallback.get("name"),
        "node_info": dict(primary.get("node_info", {})),
        "allocatable": dict(primary.get("allocatable", {})),
        "labels": dict(primary.get("labels", {})),
        "metadata_sources": list(primary.get("metadata_sources", [])),
    }
    for section in ("node_info", "allocatable", "labels"):
        for key, value in fallback.get(section, {}).items():
            if value not in (None, ""):
                merged[section].setdefault(key, value)
    for source in fallback.get("metadata_sources", []):
        if source not in merged["metadata_sources"]:
            merged["metadata_sources"].append(source)
    return merged


def missing_node_metadata(
    node_names: Sequence[str], node_infos: Sequence[Dict[str, Any]]
) -> Dict[str, List[str]]:
    expected_nodes = unique(node_names)
    if not expected_nodes:
        return {
            "execution nodes unresolved": [
                label for _section, _key, label in REQUIRED_NODE_METADATA
            ]
        }
    by_name = {str(item.get("name")): item for item in node_infos}
    missing: Dict[str, List[str]] = {}
    for node_name in expected_nodes:
        item = by_name.get(node_name, {})
        absent = [
            label
            for section, key, label in REQUIRED_NODE_METADATA
            if item.get(section, {}).get(key) in (None, "")
        ]
        if absent:
            missing[node_name] = absent
    return missing


def collect_node_info(
    node_names: Sequence[str], prom_url: Optional[str] = None
) -> List[Dict[str, Any]]:
    result: List[Dict[str, Any]] = []
    for node_name in node_names:
        record: Dict[str, Any] = {
            "name": node_name,
            "node_info": {},
            "allocatable": {},
            "labels": {},
            "metadata_sources": [],
        }
        try:
            node = kubectl_json(["get", "node", node_name])
            record = {
                "name": node_name,
                "node_info": node.get("status", {}).get("nodeInfo", {}),
                "allocatable": node.get("status", {}).get("allocatable", {}),
                "labels": node.get("metadata", {}).get("labels", {}),
                "metadata_sources": ["kubernetes-api"],
            }
        except Exception as exc:
            print(
                f"WARNING: could not read Kubernetes node {node_name} via "
                f"the API; trying Prometheus: {exc}",
                file=sys.stderr,
            )

        if prom_url and missing_node_metadata([node_name], [record]):
            try:
                fallback = collect_prometheus_node_info(prom_url, node_name)
                record = merge_node_info(record, fallback)
            except Exception as exc:
                print(
                    f"WARNING: could not read node metadata for {node_name} "
                    f"from Prometheus: {exc}",
                    file=sys.stderr,
                )
        result.append(record)
    return result


def source_files(path: Path) -> List[Path]:
    if path.is_file():
        return [path]
    allowed_suffixes = {
        ".nf",
        ".config",
        ".groovy",
        ".py",
        ".sh",
        ".json",
        ".yaml",
        ".yml",
        ".smk",
    }
    allowed_names = {"Dockerfile", "Snakefile", "environment.yml"}
    ignored_dirs = {
        ".git",
        ".nextflow",
        "__pycache__",
        "results",
        "work",
        "vivo_metadata",
    }
    files: List[Path] = []
    for candidate in path.rglob("*"):
        if not candidate.is_file():
            continue
        if any(part in ignored_dirs for part in candidate.relative_to(path).parts):
            continue
        if candidate.suffix in allowed_suffixes or candidate.name in allowed_names:
            files.append(candidate)
    return sorted(files, key=lambda item: item.relative_to(path).as_posix())


def sha256_source(path: Path) -> str:
    if not path.exists():
        raise RuntimeError(f"Code path does not exist: {path}")
    digest = hashlib.sha256()
    root = path if path.is_dir() else path.parent
    files = source_files(path)
    if not files:
        raise RuntimeError(f"No source files found under {path}")
    for source_file in files:
        relative = source_file.relative_to(root).as_posix()
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        with source_file.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        digest.update(b"\0")
    return digest.hexdigest()


def commit_url(repo_url: Optional[str], commit: Optional[str]) -> Optional[str]:
    """Build a clickable commit URL from a repo URL and a commit SHA.

    Supports GitHub and GitLab layouts. Returns None if either input is
    missing or the host is unknown, so nothing bogus is emitted.
    """
    if not repo_url or not commit:
        return None
    url = repo_url.strip().rstrip("/")
    if url.endswith(".git"):
        url = url[: -len(".git")]
    if "github.com" in url:
        return f"{url}/commit/{commit}"
    if "gitlab" in url:
        return f"{url}/-/commit/{commit}"
    return None


def require_http_url(value: str, field_name: str) -> str:
    parsed = urllib.parse.urlparse(value)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise RuntimeError(
            f"Input dataset {field_name} must be an absolute HTTP(S) URL"
        )
    return value


def load_input_datasets(path_value: Optional[str]) -> List[InputDatasetMetadata]:
    """Load generic VIVO InputDataset descriptions from a JSON file."""
    if not path_value:
        return []
    path = Path(path_value).expanduser().resolve()
    if not path.is_file():
        raise RuntimeError(f"Input dataset metadata file not found: {path}")
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RuntimeError(
            f"Cannot read input dataset metadata from {path}: {exc}"
        ) from exc
    if not isinstance(payload, dict) or payload.get("schema_version") != 1:
        raise RuntimeError(
            "Input dataset metadata must be an object with schema_version 1"
        )
    records = payload.get("datasets")
    if not isinstance(records, list):
        raise RuntimeError("Input dataset metadata must contain a datasets list")

    allowed_fields = {
        field.name
        for field in fields(InputDatasetMetadata)
    }
    url_fields = {
        "access_instructions_url",
        "checksum_manifest_url",
        "upstream_source_url",
        "format_documentation_url",
    }
    url_list_fields = {"upstream_source_urls"}
    datasets: List[InputDatasetMetadata] = []
    seen_uris: Set[str] = set()
    for index, record in enumerate(records, start=1):
        if not isinstance(record, dict):
            raise RuntimeError(f"Input dataset {index} must be a JSON object")
        unknown_fields = sorted(set(record) - allowed_fields)
        if unknown_fields:
            raise RuntimeError(
                f"Input dataset {index} has unknown fields: {unknown_fields}"
            )
        uri = record.get("uri")
        label = record.get("label")
        if not isinstance(uri, str) or not uri.strip():
            raise RuntimeError(
                f"Input dataset {index} requires a non-empty uri"
            )
        require_http_url(uri, "uri")
        if uri in seen_uris:
            raise RuntimeError(f"Duplicate input dataset URI: {uri}")
        if not isinstance(label, str) or not label.strip():
            raise RuntimeError(
                f"Input dataset {index} requires a non-empty label"
            )
        for field_name in url_fields:
            value = record.get(field_name)
            if value is not None:
                if not isinstance(value, str) or not value.strip():
                    raise RuntimeError(
                        f"Input dataset {index} {field_name} must be a URL string"
                    )
                require_http_url(value, field_name)
        normalized_record = dict(record)
        for field_name in url_list_fields:
            values = record.get(field_name, [])
            if not isinstance(values, list):
                raise RuntimeError(
                    f"Input dataset {index} {field_name} must be a list"
                )
            normalized_values: List[str] = []
            for value in values:
                if not isinstance(value, str) or not value.strip():
                    raise RuntimeError(
                        f"Input dataset {index} {field_name} must contain "
                        "only non-empty URL strings"
                    )
                require_http_url(value, field_name)
                if value not in normalized_values:
                    normalized_values.append(value)
            normalized_record[field_name] = tuple(normalized_values)
        for field_name in ("link_to_workflow", "link_to_run"):
            value = record.get(field_name, True)
            if not isinstance(value, bool):
                raise RuntimeError(
                    f"Input dataset {index} {field_name} must be true or false"
                )
        datasets.append(InputDatasetMetadata(**normalized_record))
        seen_uris.add(uri)
    return datasets


def git_metadata(code_path: Path) -> Tuple[Optional[str], Optional[bool]]:
    cwd = code_path if code_path.is_dir() else code_path.parent
    try:
        commit = run_cmd(["git", "-C", str(cwd), "rev-parse", "HEAD"]).strip()
        dirty = bool(
            run_cmd(["git", "-C", str(cwd), "status", "--porcelain"]).strip()
        )
        return commit or None, dirty
    except Exception:
        return None, None


def images_from_code(code_path: Path) -> List[str]:
    result: List[str] = []
    for source_file in source_files(code_path):
        if source_file.suffix != ".config":
            continue
        text = source_file.read_text(encoding="utf-8", errors="replace")
        for image in CONTAINER_RE.findall(text):
            if image not in result:
                result.append(image)
    return result


def slugify(text: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return slug or "item"


def ttl_escape(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\r", "\\r")
        .replace("\n", "\\n")
    )


def ttl_literal(value: Any, datatype: Optional[str] = None) -> str:
    if isinstance(value, bool):
        return f"\"{'true' if value else 'false'}\"^^xsd:boolean"
    if isinstance(value, int):
        return f'"{value}"^^{datatype or "xsd:integer"}'
    if isinstance(value, float):
        return f'"{repr(value)}"^^{datatype or "xsd:double"}'
    literal = f'"{ttl_escape(str(value))}"'
    return f"{literal}^^{datatype}" if datatype else literal


def ttl_uri(value: str) -> str:
    return f"<{value}>"


def ttl_label(value: str) -> str:
    return f"{ttl_literal(value)}@en"


def energy_measurement_coverage(
    measured_pods: Optional[int], pod_count: int
) -> Optional[str]:
    """Share of a run's pods whose energy was measured: '14.3% (40 of 280 pods)'."""
    if measured_pods is None or pod_count <= 0:
        return None
    percent = f"{100 * measured_pods / pod_count:.1f}"
    if percent.endswith(".0"):
        percent = percent[:-2]
    unit = "pod" if pod_count == 1 else "pods"
    return f"{percent}% ({measured_pods} of {pod_count} {unit})"


# Pods that belong to a node rather than to a workload: daemons that run on
# every node (DaemonSet) and static pods of the node itself.
NODE_DAEMON_KINDS = {"DaemonSet", "Node"}
NODE_USE_MAX_OTHER_CPUS_DEFAULT = 0.5


def node_use_text(exclusive: bool, other_cpus: float, node_count: int) -> str:
    """Value of rm:nodeUse: 'exclusive (...)' or 'non-exclusive (...)'."""
    nodes = "node" if node_count == 1 else f"{node_count} nodes"
    return (
        f"{'exclusive' if exclusive else 'non-exclusive'} (other workloads "
        f"used {other_cpus:.2f} CPUs on average on the run's {nodes})"
    )


def kubernetes_node_use(
    prom_url: str,
    node_names: Sequence[str],
    own_pods: Optional[Iterable[Optional[str]]],
    start: datetime,
    end: datetime,
    max_other_cpus: float = NODE_USE_MAX_OTHER_CPUS_DEFAULT,
    own_namespace: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    """Whether a run had its Kubernetes nodes to itself.

    Looks at every pod that was on the run's nodes between start and end
    (kube_pod_info) and adds up the CPU time of the pods that are neither part
    of the run nor node daemons (DaemonSet or static pods). Divided by the
    length of the window this is the average number of CPUs other workloads
    kept busy on the run's nodes. The run is 'exclusive' when that is at most
    max_other_cpus: nobody else used the nodes, whether they are reserved for
    one person or just happened to be idle.

    own_pods are the run's pods (task pods and the engine's driver pod). When
    own_pods is None, every pod of own_namespace counts as the run's; this is
    for runs whose pod names are no longer known.

    Returns None when Prometheus has no pod records for the nodes and window
    (for example because the run is older than the retention time).
    """
    nodes = unique(node_names)
    if not nodes:
        return None
    window = seconds_between(start, end)
    at = int(end.timestamp())
    node_regex = "|".join(name.replace(".", "[.]") for name in nodes)
    info = prom_query(
        prom_url,
        "max by (namespace, pod, node, created_by_kind) (max_over_time("
        f'kube_pod_info{{node=~"{node_regex}"}}[{window}s] @ {at}))',
    )
    if not info:
        return None
    usage = prom_query(
        prom_url,
        "sum by (namespace, pod) (increase(container_cpu_usage_seconds_total"
        f'{{container!="",container!="POD"}}[{window}s] @ {at}))',
    )
    cpu_seconds: Dict[Tuple[str, str], float] = {}
    for row in usage:
        metric = row.get("metric", {})
        try:
            value = float(row["value"][1])
        except (KeyError, IndexError, TypeError, ValueError):
            continue
        if math.isfinite(value):
            cpu_seconds[(metric.get("namespace", ""), metric.get("pod", ""))] = value

    own = None if own_pods is None else {name for name in own_pods if name}
    seen: set = set()
    totals = {"run": 0.0, "daemons": 0.0, "other": 0.0}
    other_by_namespace: Dict[str, float] = {}
    own_found = 0
    for row in info:
        metric = row.get("metric", {})
        key = (metric.get("namespace", ""), metric.get("pod", ""))
        if key in seen:
            continue
        seen.add(key)
        used = cpu_seconds.get(key, 0.0)
        if (key[1] in own) if own is not None else (key[0] == own_namespace):
            totals["run"] += used
            own_found += 1
        elif metric.get("created_by_kind") in NODE_DAEMON_KINDS:
            totals["daemons"] += used
        else:
            totals["other"] += used
            other_by_namespace[key[0]] = other_by_namespace.get(key[0], 0.0) + used
    other_cpus = totals["other"] / window
    exclusive = other_cpus <= max_other_cpus
    return {
        "exclusive": exclusive,
        "text": node_use_text(exclusive, other_cpus, len(nodes)),
        "nodes": nodes,
        "window_seconds": window,
        "max_other_cpus": max_other_cpus,
        "other_cpus": other_cpus,
        "run_cpus": totals["run"] / window,
        "node_daemon_cpus": totals["daemons"] / window,
        "run_pods_found": own_found,
        "pods_on_nodes": len(seen),
        "other_cpu_seconds_by_namespace": dict(
            sorted(other_by_namespace.items(), key=lambda item: -item[1])[:10]
        ),
    }


def add_resource(
    lines: List[str],
    subject: str,
    predicates: Sequence[Tuple[str, str]],
) -> None:
    lines.append(subject)
    for index, (predicate, obj) in enumerate(predicates):
        punctuation = "." if index == len(predicates) - 1 else ";"
        lines.append(f"  {predicate} {obj} {punctuation}")
    lines.append("")


def local_naive_iso(value: datetime) -> str:
    return (
        value.astimezone(BERLIN_TZ)
        .replace(tzinfo=None, microsecond=0)
        .isoformat()
    )


def format_run_title(start: datetime, end: datetime) -> str:
    start_local = start.astimezone(BERLIN_TZ)
    end_local = end.astimezone(BERLIN_TZ)
    timezone_name = start_local.tzname() or "Europe/Berlin"
    if start_local.date() == end_local.date():
        return (
            f"run {start_local.strftime('%Y-%m-%d %H:%M')}"
            f"\N{EN DASH}{end_local.strftime('%H:%M')} {timezone_name}"
        )
    return (
        f"run {start_local.strftime('%Y-%m-%d %H:%M')}"
        f"\N{EN DASH}{end_local.strftime('%Y-%m-%d %H:%M')} {timezone_name}"
    )


def append_metric_predicates(
    predicates: List[Tuple[str, str]],
    summary: Dict[str, Any],
    methods: Dict[str, str],
    energy_metric: Optional[str],
    carbon_info: CarbonIntensityInfo,
) -> None:
    if summary["cpu_seconds"] is not None:
        predicates.append(
            ("rm:cpuTimeSeconds", ttl_literal(summary["cpu_seconds"]))
        )
    predicates.append(
        ("rm:cpuTimeCalculationMethod", ttl_literal(methods["cpu"]))
    )
    if summary["memory_peak_gb"] is not None:
        predicates.append(
            ("rm:memoryPeakGB", ttl_literal(summary["memory_peak_gb"]))
        )
    if summary["memory_avg_gb"] is not None:
        predicates.append(
            ("rm:memoryAvgGB", ttl_literal(summary["memory_avg_gb"]))
        )
    predicates.append(
        ("rm:memoryCalculationMethod", ttl_literal(methods["memory"]))
    )
    if summary["energy_kwh"] is not None:
        predicates.append(
            ("rm:energyKWh", ttl_literal(summary["energy_kwh"]))
        )
    if summary["carbon_kg"] is not None:
        predicates.append(
            ("rm:carbonEmissionKgCO2e", ttl_literal(summary["carbon_kg"]))
        )
    # rm:carbonIntensityKgCO2ePerKWh dropped 2026-08-05: same value as
    # rm:carbonIntensityAssumptionKgCO2ePerKWh (below), and never declared in
    # VIVO. The Assumption predicate is the one that displays.
    predicates.append(
        (
            "rm:carbonIntensityAssumptionKgCO2ePerKWh",
            ttl_literal(carbon_info.kg_per_kwh),
        )
    )
    predicates.extend(
        [
            (
                "rm:carbonIntensitySource",
                ttl_literal(carbon_info.source),
            ),
            (
                "rm:energyMetricSource",
                ttl_literal(energy_metric or "none"),
            ),
            (
                "rm:energyCalculationMethod",
                ttl_literal(methods["energy"]),
            ),
            (
                "rm:energyCalculationUsesFallbackEstimate",
                ttl_literal(bool(summary["energy_estimated"])),
            ),
            (
                "rm:carbonCalculationMethod",
                ttl_literal(methods["carbon"]),
            ),
        ]
    )
    if carbon_info.source_uri:
        predicates.append(
            (
                "rm:carbonIntensitySourceLink",
                ttl_literal(carbon_info.source_uri, "xsd:anyURI"),
            )
        )
    if carbon_info.zone:
        predicates.append(
            ("rm:carbonIntensityZone", ttl_literal(carbon_info.zone))
        )
    if carbon_info.point_count:
        predicates.append(
            (
                "rm:carbonIntensityDataPointCount",
                ttl_literal(carbon_info.point_count, "xsd:integer"),
            )
        )
    if carbon_info.start:
        predicates.append(
            (
                "rm:carbonIntensityWindowStart",
                ttl_literal(carbon_info.start, "xsd:dateTime"),
            )
        )
    if carbon_info.end:
        predicates.append(
            (
                "rm:carbonIntensityWindowEnd",
                ttl_literal(carbon_info.end, "xsd:dateTime"),
            )
        )
    predicates.append(
        (
            "rm:carbonIntensityIncludesEstimatedData",
            ttl_literal(carbon_info.includes_estimates),
        )
    )
    predicates.append(
        (
            "rm:carbonIntensityEmissionsBasis",
            ttl_literal(carbon_info.emissions_basis),
        )
    )
    if carbon_info.temporal_granularity:
        predicates.append(
            (
                "rm:carbonIntensityTemporalGranularity",
                ttl_literal(carbon_info.temporal_granularity),
            )
        )


# ---------------------------------------------------------------------------
# FONDA 2026-10-20: whole-node energy, idle power, power over time and hourly
# grid carbon for a run that had ONE node to itself (rm:nodeUse "exclusive").
# Such a run is accounted like an exclusive HPC@HU job: its energy becomes the
# node's measured energy during the run (Kepler's kepler_node_platform_joules_total,
# the node's ACPI power meter) instead of the sum of its pods' Kepler shares,
# which misses pods that finish between Kepler readings. Adds the properties the
# run page charts use (idle vs. work, power over time, "was the timing green?"):
# rm:nodeIdlePowerW, rm:energyAboveIdleKWh, rm:nodePowerAvgW, rm:nodePowerMaxW,
# rm:nodePowerReadings(+Method), rm:nodeConditionsMethod and, when Electricity
# Maps' hourly history covers the run, time-matched carbon and
# rm:gridCarbonIntensityHours(+Method). Runs on several nodes or shared nodes
# are published exactly as before. Set FONDA_NODE_POWER=0 to switch it off.
# Publish at least 12 minutes after the run ended (quiet window after the run)
# and within 24 hours (Electricity Maps' history covers the last 24 hours).
# ---------------------------------------------------------------------------
NODE_POWER_METRIC = "kepler_node_platform_joules_total"
NODE_POWER_IDLE_WINDOW = 600
NODE_POWER_IDLE_GAP = 60
NODE_POWER_BUSY_CPUS_WARN = 2.0
NODE_POWER_MAX_POINTS = 600
NODE_POWER_HOURS_AROUND = 24
NODE_POWER_EM_HISTORY = "https://api.electricitymaps.com/v4/carbon-intensity/history"
NODE_POWER_EM_PAST_RANGE = "https://api.electricitymaps.com/v4/carbon-intensity/past-range"
NODE_POWER_WHOLE_NODE = "100% of the node (whole node, measured)"


def _np_result(data: Dict[str, Any], query: str) -> Any:
    if data.get("status") != "success":
        raise RuntimeError(f"Prometheus query failed: {query}")
    return data["data"]["result"]


def _np_instant(prom_url: str, query: str, at: float) -> Optional[float]:
    result = _np_result(http_get_json(f"{prom_url.rstrip('/')}/api/v1/query",
                                      {"query": query, "time": f"{at:.3f}"}), query)
    values = []
    for item in result:
        try:
            value = float(item["value"][1])
        except (KeyError, IndexError, TypeError, ValueError):
            continue
        if math.isfinite(value):
            values.append(value)
    return sum(values) if values else None


def _np_range(prom_url: str, query: str, start: float, end: float, step: int) -> List[Tuple[float, float]]:
    result = _np_result(http_get_json(f"{prom_url.rstrip('/')}/api/v1/query_range",
                                      {"query": query, "start": f"{start:.3f}", "end": f"{end:.3f}",
                                       "step": f"{step}s"}), query)
    points: Dict[float, float] = {}
    for item in result:
        for t, v in item.get("values", []):
            try:
                t, v = float(t), float(v)
            except (TypeError, ValueError):
                continue
            if math.isfinite(v):
                points[t] = points.get(t, 0.0) + v
    return sorted(points.items())


def _np_selector(node: str) -> str:
    return f'{NODE_POWER_METRIC}{{instance="{prometheus_label_value(node)}"}}'


def node_power_readings(prom_url: str, node: str, start: float, end: float,
                        interval: float) -> Tuple[List[Tuple[float, float]], int, int]:
    """[(seconds since the run start, watts)] from the run start to the run end: each value is the
    average power over `window` seconds centred on its time, every `step` seconds, plus one value
    exactly at the run's end."""
    step = max(5, int(round(interval)))
    window = max(30, int(math.ceil(2 * interval)) + 1)
    half = window / 2
    query = f"sum(rate({_np_selector(node)}[{window}s]))"
    points = [(t - half - start, w) for t, w in _np_range(prom_url, query, start + half, end + half, step)]
    points = [(o, w) for o, w in points if -1 <= o <= end - start + 1]
    if not points or end - start - points[-1][0] > 1:
        last = _np_instant(prom_url, query, end + half)
        if last is not None:
            points.append((end - start, last))
    if len(points) > NODE_POWER_MAX_POINTS:
        width = (end - start) / NODE_POWER_MAX_POINTS
        bins: Dict[int, List[float]] = {}
        for offset, w in points:
            bins.setdefault(min(NODE_POWER_MAX_POINTS - 1, max(0, int(offset // width))), []).append(w)
        points = [((i + 0.5) * width, sum(v) / len(v)) for i, v in sorted(bins.items())]
    return points, step, window


def _np_hour(epoch: float) -> str:
    return datetime.fromtimestamp(epoch, timezone.utc).strftime("%Y-%m-%dT%H:%MZ")


def _np_literal_value(obj: str) -> str:
    """Lexical value of a literal written by ttl_literal()."""
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


def _np_grid_history(token: str, zone: str, granularity: str = "hourly", start: Optional[float] = None,
                     end: Optional[float] = None) -> Tuple[str, List[Dict[str, Any]]]:
    """Grid intensity of the last 24 hours (history), or of [start, end) rounded out to whole intervals
    (past-range). granularity: "hourly" or "15_minutes"; each point carries its length in seconds."""
    seconds = 900 if granularity == "15_minutes" else 3600
    params = {"zone": zone, "temporalGranularity": granularity, "emissionFactorType": "lifecycle",
              "flowTraced": "true"}
    endpoint = NODE_POWER_EM_HISTORY
    if start is not None and end is not None:
        endpoint = NODE_POWER_EM_PAST_RANGE
        params["start"] = datetime.fromtimestamp(math.floor(start / seconds) * seconds, timezone.utc).strftime(
            "%Y-%m-%dT%H:%M:%SZ")
        params["end"] = datetime.fromtimestamp(math.ceil(end / seconds) * seconds, timezone.utc).strftime(
            "%Y-%m-%dT%H:%M:%SZ")
    url = endpoint + "?" + urllib.parse.urlencode(params)
    payload = http_get_json(endpoint, params, {"auth-token": token})
    if payload.get("zone") != zone or payload.get("temporalGranularity") != granularity:
        raise ValueError("unexpected Electricity Maps zone or time resolution")
    rows = payload.get("history", payload.get("data"))
    if not isinstance(rows, list):
        raise ValueError("no Electricity Maps data")
    points = []
    for row in rows:
        if row.get("emissionFactorType") != "lifecycle" or row.get("flowTraced") is not True:
            raise ValueError("unexpected Electricity Maps emissions basis")
        value = row.get("carbonIntensity", row.get("value"))
        if value is None or isinstance(value, bool):
            continue
        points.append({"begin": datetime.fromisoformat(str(row["datetime"]).replace("Z", "+00:00")).timestamp(),
                       "g_per_kwh": float(value), "estimated": bool(row.get("isEstimated", False)),
                       "seconds": seconds})
    return url, sorted(points, key=lambda p: p["begin"])


def _np_covered(points: List[Dict[str, Any]], start: float, end: float) -> List[Dict[str, Any]]:
    """The records (hours or quarter-hours) that cover every instant of the run, cut to the run."""
    pieces = []
    for point in points:
        begin, finish = point["begin"], point["begin"] + point.get("seconds", 3600)
        if finish <= start or begin >= end:
            continue
        pieces.append(dict(point, start=max(begin, start), end=min(finish, end)))
    cursor = start
    for piece in pieces:
        if abs(piece["start"] - cursor) > 1e-6:
            raise ValueError("Electricity Maps history does not cover the run without gaps")
        cursor = piece["end"]
    if not pieces or abs(cursor - end) > 1e-6:
        raise ValueError("Electricity Maps history does not cover the run")
    return pieces


def _np_shares(pieces: List[Dict[str, Any]], readings: List[Tuple[float, float]], start: float) -> List[float]:
    """Share of the run's energy in each piece, from the power readings (time share if too few)."""
    points = [(start + o, w) for o, w in readings]

    def energy_in(a: float, b: float) -> Optional[float]:
        if len(points) < 2:
            return None
        total = 0.0
        for (t0, w0), (t1, w1) in zip(points, points[1:]):
            lo, hi = max(a, t0), min(b, t1)
            if hi <= lo or t1 <= t0:
                continue
            f0 = w0 + (w1 - w0) * (lo - t0) / (t1 - t0)
            f1 = w0 + (w1 - w0) * (hi - t0) / (t1 - t0)
            total += (f0 + f1) / 2 * (hi - lo)
        return total

    parts = [energy_in(p["start"], p["end"]) for p in pieces]
    if any(p is None for p in parts) or sum(p or 0 for p in parts) <= 0:
        parts = [p["end"] - p["start"] for p in pieces]
    total = sum(parts)
    return [p / total for p in parts]


# FONDA 2026-10-20 (2): node conditions of a run that had ONE node to itself, as for HPC@HU jobs:
# rm:nodeCpuUtilizationAvgPercent (busy CPUs of the node), rm:cpuEfficiencyPercent (the run's CPU time /
# (node CPUs x duration)) and, when the node reports fan sensors to Prometheus, rm:fanSpeedAvgRPM. Each value
# is explained in rm:nodeConditionsMethod. The Nextflow driver's pod is found in the debug log ("Process:
# PID@HOST"; in a pod HOST is the pod name) and counted as part of the run.
NODE_CONDITIONS_FANS = ('(node_hwmon_fan_rpm > 0) * on(instance) group_left() '
                        'max by (instance) (node_uname_info{{nodename="{node}"}})')


def driver_pod_from_log(debug_log: Optional[str]) -> Optional[str]:
    """The pod the Nextflow driver ran in: HOST of the debug log line '  Process: PID@HOST [IP]'."""
    match = re.search(r"^\s*Process:\s*\d+@([a-z0-9](?:[-a-z0-9.]*[a-z0-9])?)\s", debug_log or "", re.MULTILINE)
    return match.group(1) if match else None


def node_conditions_k8s(args: argparse.Namespace, run_predicates: List[Tuple[str, str]], node: str,
                        start: float, end: float, duration: float,
                        interval: float) -> Tuple[Dict[str, str], List[str], Dict[str, Any]]:
    """New properties, sentences for rm:nodeConditionsMethod and a summary for the metrics audit."""
    prom = args.prom_url
    sel = prometheus_label_value(node)
    seconds = max(1, int(round(duration)))
    cpus = _np_instant(prom, f'max(machine_cpu_cores{{node="{sel}"}})', end)
    cpu_source = "machine_cpu_cores, cAdvisor"
    if not cpus:
        cpus = _np_instant(prom, f'max(kube_node_status_capacity{{node="{sel}",resource="cpu"}})', end)
        cpu_source = "kube_node_status_capacity, kube-state-metrics"
    if not cpus or cpus <= 0:
        raise ValueError(f"the number of CPUs of node {node} is unknown")
    cpus = int(round(cpus))
    new: Dict[str, str] = {}
    texts: List[str] = []
    summary: Dict[str, Any] = {"node_cpus": cpus}

    busy = _np_instant(prom, f'sum(increase(container_cpu_usage_seconds_total{{id="/",node="{sel}"}}'
                             f'[{seconds}s]))', end)
    if busy is not None:
        util = 100 * busy / (cpus * duration)
        new["rm:nodeCpuUtilizationAvgPercent"] = ttl_literal(round(util, 1))
        texts.append(f"Node CPU utilisation: CPU time of all processes on the node (cAdvisor, "
                     f"container_cpu_usage_seconds_total of the node's root cgroup) {busy:.0f} s / ({cpus} CPUs "
                     f"({cpu_source}) x {duration:.0f} s) = {util:.1f}% ({busy / duration:.1f} of {cpus} CPUs "
                     "busy on average).")
        summary["node_cpu_utilization_percent"] = util

    task_literal = dict(run_predicates).get("rm:cpuTimeSeconds")
    if task_literal:
        task_s = float(_np_literal_value(task_literal))
        driver = getattr(args, "detected_driver_pod", None)
        driver_s = None
        if driver:
            namespace = prometheus_label_value(getattr(args, "namespace", "") or "")
            driver_s = _np_instant(prom, f'sum(increase(container_cpu_usage_seconds_total{{namespace="{namespace}",'
                                         f'pod="{prometheus_label_value(driver)}",container!="",container!="POD"}}'
                                         f'[{seconds}s]))', end)
        run_s = task_s + (driver_s or 0.0)
        efficiency = 100 * run_s / (cpus * duration)
        new["rm:cpuEfficiencyPercent"] = ttl_literal(round(efficiency, 1))
        driver_text = (f" + the Nextflow driver pod {driver} {driver_s:.0f} s from cAdvisor" if driver_s is not None
                       else ", without the Nextflow driver, whose pod was not found")
        texts.append(f"CPU efficiency: run CPU time {run_s:.0f} s (tasks {task_s:.0f} s from the Nextflow trace"
                     f"{driver_text}) / ({cpus} CPUs of the node, which the run had to itself, x {duration:.0f} s) "
                     f"= {efficiency:.1f}%.")
        summary.update(cpu_efficiency_percent=efficiency, task_cpu_seconds=task_s, driver_pod=driver,
                       driver_cpu_seconds=driver_s)

    fans = NODE_CONDITIONS_FANS.format(node=sel)
    step = max(5, int(round(interval)))
    try:
        averages = [w for _, w in _np_range(prom, f"avg({fans})", start, end, step)]
        highest = [w for _, w in _np_range(prom, f"max({fans})", start, end, step)]
        count = _np_instant(prom, f"count({fans})", end)
    except (RuntimeError, ValueError, KeyError, TypeError, OSError, urllib.error.URLError):
        averages = []
    if averages:
        avg_rpm = sum(averages) / len(averages)
        max_rpm = max(highest or averages)
        new["rm:fanSpeedAvgRPM"] = ttl_literal(float(round(avg_rpm)))
        texts.append(f"Fan speed: fan sensors of the node (node_exporter, node_hwmon_fan_rpm), "
                     f"{int(count or 0)} fans, {len(averages)} readings: average {avg_rpm:.0f} rpm (mean of the fans, "
                     f"over time), highest {max_rpm:.0f} rpm.")
        summary.update(fan_avg_rpm=avg_rpm, fan_max_rpm=max_rpm, fan_count=count)
    else:
        summary["fans"] = "the node reports no fan sensors to Prometheus"
    return new, texts, summary


def node_power_apply(
    args: argparse.Namespace,
    run_predicates: List[Tuple[str, str]],
    node_names: Sequence[str],
    node_use: Optional[Dict[str, Any]],
    run_start: datetime,
    run_end: datetime,
    now: Optional[float] = None,
) -> Dict[str, Any]:
    """Replace the energy of an exclusive single-node run by the node's measured energy and add
    idle power, power readings and hourly grid carbon. Changes run_predicates in place; returns
    a summary for the metrics audit."""
    nodes = unique(node_names)
    if os.environ.get("FONDA_NODE_POWER", "1") == "0":
        return {"applied": False, "reason": "switched off (FONDA_NODE_POWER=0)"}
    if len(nodes) != 1:
        return {"applied": False, "reason": f"the run used {len(nodes)} nodes"}
    if not node_use or not node_use.get("exclusive"):
        return {"applied": False, "reason": "the run did not have its node to itself"}
    prom_url = getattr(args, "prom_url", "") or ""
    if not prom_url:
        return {"applied": False, "reason": "no Prometheus URL"}
    node = nodes[0]
    start, end = run_start.timestamp(), run_end.timestamp()
    duration = end - start
    now = datetime.now(timezone.utc).timestamp() if now is None else now
    try:
        if duration <= 0:
            raise ValueError("run end is not after its start")
        counts = _np_result(http_get_json(f"{prom_url.rstrip('/')}/api/v1/query",
                                          {"query": f"count_over_time({_np_selector(node)}[600s])",
                                           "time": f"{end:.3f}"}), "count_over_time")
        samples = max((float(r["value"][1]) for r in counts), default=0.0)
        if samples < 2:
            raise ValueError(f"Prometheus has no {NODE_POWER_METRIC} for node {node}")
        interval = 600.0 / samples
        seconds = max(1, int(round(duration)))
        energy_j = _np_instant(prom_url, f"sum(increase({_np_selector(node)}[{seconds}s]))", end)
        if energy_j is None or energy_j <= 0:
            raise ValueError(f"no {NODE_POWER_METRIC} increase for node {node} during the run")
        windows = []
        ends = [start - NODE_POWER_IDLE_GAP]
        after = end + NODE_POWER_IDLE_GAP + NODE_POWER_IDLE_WINDOW
        if now >= after + 30:
            ends.append(after)
        for window_end in ends:
            joules = _np_instant(prom_url, f"sum(increase({_np_selector(node)}[{NODE_POWER_IDLE_WINDOW}s]))",
                                 window_end)
            busy = _np_instant(prom_url, f'sum(rate(container_cpu_usage_seconds_total{{id="/",node="'
                                         f'{prometheus_label_value(node)}"}}[{NODE_POWER_IDLE_WINDOW}s]))', window_end)
            if joules is not None:
                windows.append({"start": window_end - NODE_POWER_IDLE_WINDOW, "end": window_end,
                                "watts": joules / NODE_POWER_IDLE_WINDOW, "busy_cpus": busy})
        if not windows:
            raise ValueError("no node power before the run; cannot determine the idle power")
        readings, step, rate_window = node_power_readings(prom_url, node, start, end, interval)
    except (RuntimeError, ValueError, KeyError, TypeError, OSError, urllib.error.URLError) as exc:
        print(f"WARNING: node power not added ({exc}); the run keeps its pod energy.", file=sys.stderr)
        return {"applied": False, "reason": str(exc)}

    idle_w = sum(w["watts"] for w in windows) / len(windows)
    above_kwh = (energy_j - idle_w * duration) / 3_600_000
    energy_kwh = energy_j / 3_600_000
    max_w = max((w for _, w in readings), default=None)
    warnings = []
    for w in windows:
        if w["busy_cpus"] is not None and w["busy_cpus"] > NODE_POWER_BUSY_CPUS_WARN:
            warnings.append(f"the node had {w['busy_cpus']:.1f} busy CPUs in the quiet window "
                            f"{_np_hour(w['start'])[11:16]}-{_np_hour(w['end'])[11:16]} UTC; the idle power may be "
                            "too high")
    if len(windows) == 1:
        warnings.append("only the window before the run was used (the window after it had not passed yet)")

    def window_text(w: Dict[str, Any]) -> str:
        busy = "" if w["busy_cpus"] is None else f", {w['busy_cpus']:.2f} CPUs busy on average"
        return (f"{datetime.fromtimestamp(w['start'], BERLIN_TZ):%H:%M}-"
                f"{datetime.fromtimestamp(w['end'], BERLIN_TZ):%H:%M} Berlin time: {w['watts']:.1f} W{busy}")

    values = {p: o for p, o in run_predicates}
    old_energy = values.get("rm:energyKWh")
    old_energy_kwh = float(_np_literal_value(old_energy)) if old_energy else None
    start_utc = datetime.fromtimestamp(start, timezone.utc).isoformat()
    end_utc = datetime.fromtimestamp(end, timezone.utc).isoformat()
    new: Dict[str, str] = {
        "rm:nodeIdlePowerW": ttl_literal(round(idle_w, 1)),
        "rm:energyAboveIdleKWh": ttl_literal(above_kwh),
        "rm:nodePowerAvgW": ttl_literal(round(energy_j / duration, 1)),
        "rm:nodeConditionsMethod": ttl_literal(
            f"Idle power: {idle_w:.0f} W, the mean power of node {node} (ACPI power meter, read by Kepler as "
            f"{NODE_POWER_METRIC}) in {len(windows)} quiet window{'s' if len(windows) > 1 else ''} of "
            f"{NODE_POWER_IDLE_WINDOW // 60} minutes, {NODE_POWER_IDLE_GAP} s before"
            f"{' and after' if len(windows) > 1 else ''} the run on {run_start.astimezone(BERLIN_TZ):%Y-%m-%d}: "
            + "; ".join(window_text(w) for w in windows) + ". "
            f"Energy above idle = (node energy {energy_j:.0f} J - {idle_w:.0f} W x {duration:.0f} s) = "
            f"{energy_j - idle_w * duration:.0f} J = {above_kwh:.6f} kWh."
            + ("" if not warnings else " Note: " + "; ".join(warnings) + ".")),
        "rm:energyKWh": ttl_literal(energy_kwh),
        "rm:energyMeasurementCoverage": ttl_literal(NODE_POWER_WHOLE_NODE),
        "rm:energyMetricSource": ttl_literal(f"{NODE_POWER_METRIC} (ACPI power meter of the node, read by Kepler)"),
        "rm:energyCalculationUsesFallbackEstimate": ttl_literal(False),
        "rm:energyCalculationMethod": ttl_literal(
            f"Whole-node energy: the run had node {node} to itself ({node_use.get('text', 'exclusive')}), so all of "
            f"the node's energy during the run is the run's energy, as for an exclusive HPC@HU job. Node energy = "
            f"increase of {NODE_POWER_METRIC} (the node's ACPI power meter, read by Kepler) from {start_utc} to "
            f"{end_utc} = {energy_j:.0f} J = {energy_kwh:.6f} kWh, including the node's idle power; cooling and "
            "network are excluded."
            + (f" It replaces the sum of the run's pods' Kepler shares ({old_energy_kwh:.6f} kWh), which misses "
               "pods that finished between Kepler readings." if old_energy_kwh is not None else "")),
    }
    if max_w is not None:
        new["rm:nodePowerMaxW"] = ttl_literal(round(max_w, 1))
    if len(readings) >= 3:
        new["rm:nodePowerReadings"] = ttl_literal("; ".join(f"{o:.1f} {w:.0f}" for o, w in readings))
        new["rm:nodePowerReadingsMethod"] = ttl_literal(
            f"Power of the whole node {node} from its ACPI power meter, read by Kepler ({NODE_POWER_METRIC}) and "
            f"stored in Prometheus about every {interval:.0f} s; each value is the average power over the "
            f"{rate_window} s centred on its time, every {step} s and at the run's end: {len(readings)} readings. "
            f"Each entry is the time since the run started ({start_utc}) in seconds and the node's power in watts.")

    carbon_note = None
    try:
        token = os.environ.get(getattr(args, "electricity_maps_api_token_env", "ELECTRICITY_MAPS_API_TOKEN")
                               or "ELECTRICITY_MAPS_API_TOKEN", "").strip()
        if not token:
            raise ValueError("no Electricity Maps token")
        zone = getattr(args, "electricity_maps_zone", "DE") or "DE"
        # Hourly history: the hours around the run for the run page (rm:gridCarbonIntensityHours).
        hour_error: Optional[Exception] = None
        try:
            hour_url, points = _np_grid_history(token, zone)
        except (RuntimeError, ValueError, KeyError, TypeError, OSError, urllib.error.URLError) as exc:
            hour_url, points, hour_error = "", [], exc
        # Carbon: 15-minute values of the run's own time where the account has them, else the hourly ones.
        try:
            source_url, quarter_points = _np_grid_history(token, zone, "15_minutes", start, end)
            pieces = _np_covered(quarter_points, start, end)
            granularity, unit, unit_s = "15 minutes", "quarter-hour", "15-minute"
        except (RuntimeError, ValueError, KeyError, TypeError, OSError, urllib.error.URLError):
            if hour_error is not None:
                raise hour_error
            source_url, pieces = hour_url, _np_covered(points, start, end)
            granularity, unit, unit_s = "hourly", "hour", "hourly"
        shares = _np_shares(pieces, readings, start)
        g = sum(s * p["g_per_kwh"] for s, p in zip(shares, pieces))
        intensity = g / 1000
        first = math.floor(start / 3600) * 3600 - NODE_POWER_HOURS_AROUND * 3600
        last = math.ceil(end / 3600) * 3600 + NODE_POWER_HOURS_AROUND * 3600
        hours = [p for p in points if first <= p["begin"] < last]
        detail = ", ".join(f"{_np_hour(p['begin'])[11:16]} UTC {p['g_per_kwh']:.0f} g/kWh x {s:.1%}"
                           for p, s in zip(pieces, shares))
        new.update({
            "rm:carbonIntensityAssumptionKgCO2ePerKWh": ttl_literal(intensity),
            "rm:carbonEmissionKgCO2e": ttl_literal(energy_kwh * intensity),
            "rm:carbonIntensitySource": ttl_literal(
                f"Electricity Maps {unit_s} history (zone {zone}, lifecycle, flow-traced)"),
            "rm:carbonIntensitySourceLink": ttl_literal(source_url, "xsd:anyURI"),
            "rm:carbonIntensityWindowStart": ttl_literal(
                datetime.fromtimestamp(pieces[0]["begin"], timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), "xsd:dateTime"),
            "rm:carbonIntensityWindowEnd": ttl_literal(
                datetime.fromtimestamp(pieces[-1]["begin"] + pieces[-1].get("seconds", 3600),
                                       timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "xsd:dateTime"),
            "rm:carbonIntensityDataPointCount": ttl_literal(len(pieces), "xsd:integer"),
            "rm:carbonIntensityIncludesEstimatedData": ttl_literal(any(p["estimated"] for p in pieces)),
            "rm:carbonIntensityEmissionsBasis": ttl_literal("lifecycle CO2e"),
            "rm:carbonIntensityTemporalGranularity": ttl_literal(granularity),
            "rm:carbonCalculationMethod": ttl_literal(
                f"Time-matched: the run's energy {energy_kwh:.6f} kWh x the {unit_s} carbon intensity of the grid "
                f"(Electricity Maps, zone {zone}, lifecycle, flow-traced) in the {unit}s the run used, weighted by "
                f"the run's energy in each {unit} ({detail}) = {g:.1f} g/kWh, so "
                f"{energy_kwh * intensity * 1000:.2f} g CO2e."),
        })
        if len(hours) >= 2:
            new["rm:gridCarbonIntensityHours"] = ttl_literal("; ".join(
                f"{_np_hour(p['begin'])} {p['g_per_kwh']:.1f}{'*' if p['estimated'] else ''}" for p in hours))
            new["rm:gridCarbonIntensityHoursMethod"] = ttl_literal(
                f"Hourly carbon intensity of the grid (zone {zone}) from Electricity Maps (lifecycle CO2e, "
                f"flow-traced), in grams per kWh, for the {len(hours)} hours from {_np_hour(hours[0]['begin'])} to "
                f"{_np_hour(hours[-1]['begin'] + 3600)} (UTC) that its history returned when this record was made. "
                "Each entry is the start of an hour and its intensity; * = estimated by the source. Shown on the run "
                "page next to the hour or hours the run used.")
    except (RuntimeError, ValueError, KeyError, TypeError, OSError, urllib.error.URLError) as exc:
        carbon_note = f"carbon not time-matched ({exc}); the run's intensity is applied to the node energy"
        old_intensity = values.get("rm:carbonIntensityAssumptionKgCO2ePerKWh")
        if old_intensity:
            intensity = float(_np_literal_value(old_intensity))
            old_method = _np_literal_value(values.get("rm:carbonCalculationMethod", '""'))
            new["rm:carbonEmissionKgCO2e"] = ttl_literal(energy_kwh * intensity)
            new["rm:carbonCalculationMethod"] = ttl_literal(
                (old_method + " " if old_method else "") + f"Applied to the whole-node energy {energy_kwh:.6f} kWh: "
                f"{energy_kwh * intensity * 1000:.2f} g CO2e.")

    try:
        cond_new, cond_texts, cond_summary = node_conditions_k8s(args, run_predicates, node, start, end,
                                                                 duration, interval)
    except Exception as exc:  # optional values: the publication goes on without them
        cond_new, cond_texts, cond_summary = {}, [], {"error": str(exc)}
        print(f"WARNING: node CPU utilisation, CPU efficiency and fan speed not added ({exc})", file=sys.stderr)
    new.update(cond_new)
    if cond_texts:
        new["rm:nodeConditionsMethod"] = ttl_literal(
            _np_literal_value(new["rm:nodeConditionsMethod"]) + " " + " ".join(cond_texts))
    run_predicates[:] = [(p, o) for p, o in run_predicates if p not in new] + list(new.items())
    summary = {"applied": True, "node": node, "node_energy_kwh": energy_kwh, "pod_energy_kwh": old_energy_kwh,
               "idle_w": round(idle_w, 1), "above_idle_kwh": above_kwh, "readings": len(readings),
               "quiet_windows": windows, "grid_hours": "rm:gridCarbonIntensityHours" in new,
               "carbon_note": carbon_note, "warnings": warnings}
    summary["node_conditions"] = cond_summary
    print(f"node_power: whole-node energy {energy_kwh:.6f} kWh (pods: {old_energy_kwh}), idle {idle_w:.1f} W, "
          f"above idle {above_kwh:.6f} kWh, {len(readings)} power readings, grid hours: {summary['grid_hours']}")
    for warning in warnings + ([carbon_note] if carbon_note else []):
        print(f"WARNING: {warning}", file=sys.stderr)
    return summary


def build_ttl(
    args: argparse.Namespace,
    tasks: Sequence[TaskRecord],
    stages: Sequence[Dict[str, Any]],
    pod_metrics: Dict[str, PodMetrics],
    run_start: datetime,
    run_end: datetime,
    run_status: str,
    log_metadata: Dict[str, Any],
    code_version: str,
    git_commit: Optional[str],
    git_dirty: Optional[bool],
    energy_metric: Optional[str],
    carbon_info: CarbonIntensityInfo,
    node_infos: Sequence[Dict[str, Any]],
    images: Sequence[str],
    responsible_researchers: Sequence[str],
    responsible_researcher_uris: Sequence[str],
    subproject_uris: Sequence[str],
    language_uris: Sequence[str],
    input_datasets: Sequence[InputDatasetMetadata],
    node_use: Optional[Dict[str, Any]] = None,
) -> Tuple[str, Dict[str, Any]]:
    engine_label = getattr(args, "engine_label", "Nextflow")
    base_uri = args.base_uri.rstrip("/") + "/"
    ontology_uri = (
        args.ontology_uri
        if args.ontology_uri.endswith(("#", "/"))
        else args.ontology_uri + "#"
    )
    session_key = (
        log_metadata.get("run_id")
        or log_metadata.get("session_id")
        or f"{run_start.isoformat()}-{run_end.isoformat()}"
    )
    run_identity_scope = (
        getattr(args, "run_identity_scope", "") or args.namespace
    )
    run_slug = slugify(
        f"{run_identity_scope}-{args.workflow_name}-"
        f"{session_key}-{run_start.isoformat()}"
    )
    run_uri = f"{base_uri}run/{run_slug}"
    datetime_uri = f"{base_uri}datetime/{run_slug}"
    workflow_uri = args.workflow_uri
    engine_uri = args.engine_uri
    cluster_uri = args.cluster_uri
    publication_uris = [
        value.strip()
        for value in (args.publication_uri or "").split(",")
        if value.strip()
    ]
    run_title = (
        f"{args.workflow_name} \N{MIDDLE DOT} "
        f"{format_run_title(run_start, run_end)}"
    )
    accounting_start, accounting_end = resource_accounting_window(
        tasks,
        run_start,
        run_end,
        args.include_cached_origin_metrics,
    )

    all_pod_names = unique(
        task.pod_name
        for task in tasks
        if (
            task.status != "CACHED"
            or args.include_cached_origin_metrics
        )
    )
    overall = summarize_metrics(
        all_pod_names,
        pod_metrics,
        accounting_start,
        accounting_end,
        carbon_info.kg_per_kwh,
        [
            task
            for task in tasks
            if task.status != "CACHED"
            or args.include_cached_origin_metrics
        ],
    )
    overall_methods = metric_methods(
        overall,
        len(all_pod_names),
        carbon_info,
        args.include_cached_origin_metrics,
        cluster_uri=cluster_uri,
    )
    status_counts = Counter(task.status for task in tasks)
    node_names = unique(
        metrics.node_name for metrics in pod_metrics.values()
    )

    stage_records: List[Dict[str, Any]] = []
    for stage in stages:
        stage_tasks: List[TaskRecord] = stage["tasks"]
        executed_stage_tasks = [
            task for task in stage_tasks if task.status != "CACHED"
        ]
        cached_only = not executed_stage_tasks
        if cached_only and not args.include_cached_origin_metrics:
            stage_start = run_start
            stage_end = run_start
        else:
            timed_stage_tasks = executed_stage_tasks or stage_tasks
            stage_start = min(task.submit for task in timed_stage_tasks)
            stage_end = max(
                (task.end or run_end) for task in timed_stage_tasks
            )
        stage_has_success = any(
            task.status in {"COMPLETED", "CACHED"} for task in stage_tasks
        )
        stage_status = derive_status(
            stage_tasks,
            True,
            stage_has_success
            and run_status in {"Succeeded", "Succeeded with warnings"},
        )
        stage_pods = unique(
            task.pod_name
            for task in stage_tasks
            if (
                task.status != "CACHED"
                or args.include_cached_origin_metrics
            )
        )
        stage_summary = summarize_metrics(
            stage_pods,
            pod_metrics,
            stage_start,
            stage_end,
            carbon_info.kg_per_kwh,
            [
                task
                for task in stage_tasks
                if task.status != "CACHED"
                or args.include_cached_origin_metrics
            ],
        )
        stage_methods = metric_methods(
            stage_summary,
            len(stage_pods),
            carbon_info,
            cached_only and args.include_cached_origin_metrics,
            cluster_uri=cluster_uri,
        )
        stage_key = f"{args.workflow_name}-{stage['slug']}-{session_key}"
        stage_uri = f"{base_uri}process/{slugify(stage_key)}"
        stage_records.append(
            {
                "uri": stage_uri,
                "slug": stage["slug"],
                "label": stage["label"],
                "run_label": stage_run_label(stage["label"], run_start),
                "workflow_stage_uri": workflow_stage_uri(
                    base_uri, workflow_uri, stage["slug"]
                ),
                "tasks": stage_tasks,
                "pod_names": stage_pods,
                "start": stage_start,
                "end": stage_end,
                "status": stage_status,
                "cached_only": cached_only,
                "cached_origin_metrics": (
                    cached_only and args.include_cached_origin_metrics
                ),
                "summary": stage_summary,
                "methods": stage_methods,
            }
        )

    lines = [
        "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .",
        "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .",
        "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .",
        "@prefix dcterms: <http://purl.org/dc/terms/> .",
        "@prefix vivo: <http://vivoweb.org/ontology/core#> .",
        "@prefix bibo: <http://purl.org/ontology/bibo/> .",
        "@prefix prov: <http://www.w3.org/ns/prov#> .",
        f"@prefix rm: <{ontology_uri}> .",
        f"@prefix ex: <{base_uri}> .",
        "",
    ]

    # rm:WorkflowProcessRun class declaration also removed 2026-07-30 - the
    # class exists in VIVO's TBox.
    # NOTE 2026-07-30: inline declarations of rm:hasWorkflowProcess,
    # rm:isWorkflowProcessOf, rm:workflows and rm:hasWorkflow as generic
    # rdf:Property were REMOVED. Those properties are defined in VIVO's TBox;
    # re-declaring them here wrote duplicates into vitro-kb-2, which VIVO
    # rendered as extra/empty property sections. Do not re-add them.
    add_resource(
        lines,
        ttl_uri(engine_uri),
        [
            ("rdf:type", "rm:WorkflowEngine"),
            ("rdf:type", "vivo:InformationResource"),
            ("rdfs:label", ttl_label(engine_label)),
            ("dcterms:title", ttl_label(engine_label)),
            # reverse link -> engine page's "workflows" list
            ("rm:hasWorkflow", ttl_uri(workflow_uri)),
        ],
    )
    for language_uri in language_uris:
        language_label = DEFAULT_LANGUAGE_LABELS.get(language_uri)
        if not language_label:
            continue
        add_resource(
            lines,
            ttl_uri(language_uri),
            [
                ("rdf:type", "rm:Language"),
                ("rdf:type", "vivo:InformationResource"),
                ("rdfs:label", ttl_label(language_label)),
                ("dcterms:title", ttl_label(language_label)),
                ("rm:hasWorkflow", ttl_uri(workflow_uri)),
            ],
        )
    if args.backend_uri:
        add_resource(
            lines,
            ttl_uri(args.backend_uri),
            [("rm:hasWorkflow", ttl_uri(workflow_uri))],
        )
    cluster_predicates: List[Tuple[str, str]] = [
        ("rdf:type", "rm:ComputeCluster"),
        ("rdf:type", "vivo:InformationResource"),
        ("rdfs:label", ttl_label(args.cluster_label)),
        ("dcterms:title", ttl_label(args.cluster_label)),
        ("rm:hasRun", ttl_uri(run_uri)),
        ("rm:hasWorkflow", ttl_uri(workflow_uri)),
    ]
    add_resource(lines, ttl_uri(cluster_uri), cluster_predicates)

    workflow_predicates: List[Tuple[str, str]] = [
        ("rdf:type", "rm:Workflow"),
        ("rdf:type", "vivo:InformationResource"),
        ("rdf:type", "prov:Entity"),
        ("rdfs:label", ttl_label(args.workflow_name)),
        ("dcterms:title", ttl_label(args.workflow_name)),
        ("rm:workflowName", ttl_literal(args.workflow_name)),
        ("rm:traceTypes", ttl_literal(args.trace_types)),
        ("rm:traceDataFormat", ttl_literal(args.trace_data_format)),
        ("rm:workflowEngine", ttl_uri(engine_uri)),
        # Execution Environment on the workflow individual (union domain
        # Workflow OR Workflow Run in VIVO)
        ("rm:computeCluster", ttl_uri(cluster_uri)),
    ]
    workflow_description = getattr(args, "workflow_description", "")
    if workflow_description:
        # rm:purpose is the predicate VIVO renders on the workflow page;
        # dcterms:description carries the same text under a standard term
        # for consumers reading the raw RDF.
        workflow_predicates.append(
            ("rm:purpose", ttl_label(workflow_description))
        )
        workflow_predicates.append(
            ("dcterms:description", ttl_label(workflow_description))
        )
    if args.code_uri:
        workflow_predicates.append(
            ("rm:workflowCodeLink", ttl_literal(args.code_uri, "xsd:anyURI"))
        )
    legacy_trace_archive = getattr(args, "trace_archive", "")
    workflow_trace_repository = (
        getattr(args, "workflow_trace_repository", "")
        or legacy_trace_archive
    )
    run_trace_archive = (
        getattr(args, "run_trace_archive", "")
        or legacy_trace_archive
    )
    if workflow_trace_repository:
        workflow_predicates.append(
            (
                "rm:traceArchive",
                ttl_literal(workflow_trace_repository, "xsd:anyURI"),
            )
        )
    if args.application_domain_uri:
        workflow_predicates.append(
            ("rm:applicationDomain", ttl_uri(args.application_domain_uri))
        )
    for publication_uri in publication_uris:
        workflow_predicates.append(
            ("rm:describesSoftwareExecution", ttl_uri(publication_uri))
        )
        workflow_predicates.append(
            ("rm:usedInPublication", ttl_uri(publication_uri))
        )
    if args.backend_uri:
        workflow_predicates.append(("rm:backend", ttl_uri(args.backend_uri)))
    # NOTE 2026-07-30: rm:responsibleResearcher is an OBJECT property in VIVO
    # (range Person). Literal names are no longer emitted - they created a
    # second, generic datatype property and an empty section on every workflow
    # page. Use --responsible-researcher-uri instead; any plain names passed
    # via --responsible-researcher are only warned about here.
    for researcher in responsible_researchers:
        print(
            "WARNING: ignoring literal responsible researcher "
            f"'{researcher}' - pass a person URI via --responsible-researcher-uri",
            file=sys.stderr,
        )
    for researcher_uri in responsible_researcher_uris:
        workflow_predicates.append(
            ("rm:responsibleResearcher", ttl_uri(researcher_uri))
        )
    for subproject_uri in subproject_uris:
        workflow_predicates.append(("rm:subproject", ttl_uri(subproject_uri)))
    for language_uri in language_uris:
        workflow_predicates.append(("rm:language", ttl_uri(language_uri)))
    for dataset in input_datasets:
        if dataset.link_to_workflow:
            workflow_predicates.append(
                ("rm:hasUsedInputData", ttl_uri(dataset.uri))
            )
    workflow_predicates.extend(
        [
            ("rm:hasRun", ttl_uri(run_uri)),
            ("rm:hasWorkflowRun", ttl_uri(run_uri)),
        ]
    )
    for stage in stage_records:
        workflow_predicates.append(
            ("rm:hasWorkflowStage", ttl_uri(stage["workflow_stage_uri"]))
        )
    add_resource(lines, ttl_uri(workflow_uri), workflow_predicates)
    for researcher_uri in responsible_researcher_uris:
        add_resource(
            lines,
            ttl_uri(researcher_uri),
            [("rm:workflows", ttl_uri(workflow_uri))],
        )
    for subproject_uri in subproject_uris:
        add_resource(
            lines,
            ttl_uri(subproject_uri),
            [("rm:hasWorkflow", ttl_uri(workflow_uri))],
        )

    run_predicates: List[Tuple[str, str]] = [
        ("rdf:type", "rm:RunMetadata"),
        ("rdf:type", "vivo:InformationResource"),
        ("rdf:type", "prov:Activity"),  # an execution: prov:startedAtTime/endedAtTime have domain prov:Activity
        ("rdfs:label", ttl_label(run_title)),
        ("dcterms:title", ttl_label(run_title)),
        ("rm:workflow", ttl_uri(workflow_uri)),
        ("rm:computeCluster", ttl_uri(cluster_uri)),
        ("rm:codeVersion", ttl_literal(f"sha256:{code_version}")),
        ("rm:runStatus", ttl_literal(run_status)),
        ("rm:workflowEngine", ttl_uri(engine_uri)),
        (
            "prov:startedAtTime",
            ttl_literal(local_naive_iso(run_start), "xsd:dateTime"),
        ),
        (
            "prov:endedAtTime",
            ttl_literal(local_naive_iso(run_end), "xsd:dateTime"),
        ),
        (
            "rm:startTime",
            ttl_literal(local_naive_iso(run_start), "xsd:dateTime"),
        ),
        (
            "rm:endTime",
            ttl_literal(local_naive_iso(run_end), "xsd:dateTime"),
        ),
        (
            "rm:durationSeconds",
            ttl_literal(seconds_between(run_start, run_end), "xsd:integer"),
        ),
        (
            "rm:durationCalculationMethod",
            ttl_literal(
                getattr(
                    args,
                    "duration_calculation_method",
                    "Wall-clock time from the first to last timestamp in the "
                    "Nextflow debug log, with trace timestamps as a fallback.",
                )
            ),
        ),
        (
            "dcterms:created",
            ttl_literal(
                datetime.now(BERLIN_TZ).replace(microsecond=0).isoformat(),
                "xsd:dateTime",
            ),
        ),
        (
            "vivo:dateTimeValue",
            ttl_uri(datetime_uri),
        ),
        (
            "rm:jobName",
            ttl_literal(log_metadata.get("run_name") or args.workflow_name),
        ),
        (
            "rm:taskCount",
            ttl_literal(len(tasks), "xsd:integer"),
        ),
        (
            "rm:podCount",
            ttl_literal(len(all_pod_names), "xsd:integer"),
        ),
        (
            "rm:succeededTaskCount",
            ttl_literal(
                status_counts["COMPLETED"] + status_counts["CACHED"],
                "xsd:integer",
            ),
        ),
        (
            "rm:cachedTaskCount",
            ttl_literal(status_counts["CACHED"], "xsd:integer"),
        ),
        (
            "rm:failedTaskCount",
            ttl_literal(
                status_counts["FAILED"] + status_counts["ERROR"],
                "xsd:integer",
            ),
        ),
        (
            "rm:abortedTaskCount",
            ttl_literal(status_counts["ABORTED"], "xsd:integer"),
        ),
        (
            "rm:resourceAccountingScope",
            ttl_literal(
                getattr(
                    args,
                    "resource_accounting_scope",
                    (
                        "Current Nextflow execution plus origin pods for tasks "
                        "reused from the Nextflow cache."
                        if args.include_cached_origin_metrics
                        else "Pods executed by the current Nextflow execution."
                    ),
                )
            ),
        ),
        (
            "rm:resourceAccountingStartTime",
            ttl_literal(
                local_naive_iso(accounting_start), "xsd:dateTime"
            ),
        ),
        (
            "rm:resourceAccountingEndTime",
            ttl_literal(
                local_naive_iso(accounting_end), "xsd:dateTime"
            ),
        ),
        ("rm:traceTypes", ttl_literal(args.trace_types)),
        ("rm:traceDataFormat", ttl_literal(args.trace_data_format)),
    ]
    run_description = getattr(args, "run_description", "")
    if run_description:
        run_predicates.append(
            ("dcterms:description", ttl_label(run_description))
        )
    if args.backend_uri:
        run_predicates.append(("rm:backend", ttl_uri(args.backend_uri)))
    if run_trace_archive:
        run_predicates.append(
            ("rm:traceArchive", ttl_literal(run_trace_archive, "xsd:anyURI"))
        )
    for publication_uri in publication_uris:
        run_predicates.append(
            ("rm:describesSoftwareExecution", ttl_uri(publication_uri))
        )
    for dataset in input_datasets:
        if dataset.link_to_run:
            run_predicates.append(("rm:inputData", ttl_uri(dataset.uri)))
    if args.run_operator_uri:
        run_predicates.append(
            ("rm:runOperator", ttl_uri(args.run_operator_uri))
        )
    if engine_label.lower() == "nextflow" and log_metadata.get("session_id"):
        run_predicates.append(
            (
                "rm:nextflowSessionId",
                ttl_literal(log_metadata["session_id"]),
            )
        )
    if log_metadata.get("nextflow_version"):
        run_predicates.append(
            (
                "rm:workflowEngineVersion",
                ttl_literal(log_metadata["nextflow_version"]),
            )
        )
    if log_metadata.get("failure_reason"):
        run_predicates.append(
            (
                "rm:failureReason",
                ttl_literal(log_metadata["failure_reason"]),
            )
        )
    if git_commit:
        run_predicates.append(("rm:gitCommit", ttl_literal(git_commit)))
        # A bare SHA is only findable if the reader knows which repo it belongs
        # to, and "workflow code link" can hold several repos. Emit the full,
        # clickable commit URL as well.
        commit_link = commit_url(args.workflow_repo_url, git_commit)
        if commit_link:
            run_predicates.append(
                ("rm:codeCommitLink", ttl_literal(commit_link, "xsd:anyURI"))
            )
    # rm:codeModified removed 2026-08-05 (not used in VIVO).

    append_metric_predicates(
        run_predicates,
        overall,
        overall_methods,
        energy_metric,
        carbon_info,
    )
    coverage = energy_measurement_coverage(
        overall.get("energy_pod_count"), len(all_pod_names)
    )
    if coverage:
        run_predicates.append(
            ("rm:energyMeasurementCoverage", ttl_literal(coverage))
        )
    if node_use:
        run_predicates.append(("rm:nodeUse", ttl_literal(node_use["text"])))
    for image in images:
        run_predicates.append(("rm:containerImage", ttl_literal(image)))
    for node_name in node_names:
        # rm:nodeName dropped 2026-08-05: it duplicated rm:executionHost
        # value-for-value and was never declared in VIVO.
        run_predicates.append(("rm:executionHost", ttl_literal(node_name)))

    for node in node_infos:
        node_info = node["node_info"]
        allocatable = node["allocatable"]
        if allocatable.get("cpu"):
            run_predicates.append(
                ("rm:allocatableCpu", ttl_literal(allocatable["cpu"]))
            )
        memory_bytes = parse_k8s_bytes(str(allocatable.get("memory", "")))
        if memory_bytes is not None:
            run_predicates.append(
                (
                    "rm:allocatableMemoryGB",
                    ttl_literal(bytes_to_gb(memory_bytes)),
                )
            )
        field_map = {
            "architecture": "rm:architecture",
            "kernelVersion": "rm:kernelVersion",
            "kubeletVersion": "rm:kubeletVersion",
            "osImage": "rm:osImage",
        }
        for key, predicate in field_map.items():
            if node_info.get(key):
                run_predicates.append(
                    (predicate, ttl_literal(node_info[key]))
                )

    run_predicates.extend(
        [
            ("rm:gpuRequested", ttl_literal(False)),
            ("rm:gpuMetricsAvailable", ttl_literal(False)),
            ("rm:gpuCapableNodeUsed", ttl_literal(False)),
            ("rm:gpuUsageStatus", ttl_literal("CPU-only workflow run")),
        ]
    )
    for stage in stage_records:
        run_predicates.append(
            ("rm:hasWorkflowProcess", ttl_uri(stage["uri"]))
        )
        run_predicates.append(
            ("rm:usesWorkflowStage", ttl_uri(stage["workflow_stage_uri"]))
        )
    # FONDA 2026-10-20: a run that had one node to itself gets the whole node's measured energy, its idle
    # power, power readings and hourly grid carbon (node_power_apply).
    node_power = node_power_apply(args, run_predicates, node_names, node_use, run_start, run_end)
    add_resource(lines, ttl_uri(run_uri), run_predicates)

    for dataset in input_datasets:
        dataset_predicates: List[Tuple[str, str]] = [
            ("rdf:type", "rm:InputDataset"),
            ("rdf:type", "vivo:InformationResource"),
            ("rdf:type", "prov:Entity"),
            ("rdfs:label", ttl_label(dataset.label)),
            ("dcterms:title", ttl_label(dataset.label)),
        ]
        if dataset.description:
            dataset_predicates.append(
                ("dcterms:description", ttl_label(dataset.description))
            )
        url_predicates = (
            ("access_instructions_url", "rm:accessInstructionsURL"),
            ("checksum_manifest_url", "rm:checksumManifestURL"),
            ("upstream_source_url", "rm:upstreamSourceURL"),
            ("format_documentation_url", "rm:formatDocumentationURL"),
        )
        for field_name, predicate in url_predicates:
            value = getattr(dataset, field_name)
            if value:
                dataset_predicates.append(
                    (predicate, ttl_literal(value, "xsd:anyURI"))
                )
        for value in dataset.upstream_source_urls:
            if value != dataset.upstream_source_url:
                dataset_predicates.append(
                    (
                        "rm:upstreamSourceURL",
                        ttl_literal(value, "xsd:anyURI"),
                    )
                )
        if dataset.storage_location:
            dataset_predicates.append(
                ("rm:storageLocation", ttl_literal(dataset.storage_location))
            )
        if dataset.access_statement:
            dataset_predicates.append(
                ("rm:accessStatement", ttl_label(dataset.access_statement))
            )
        if dataset.link_to_workflow:
            dataset_predicates.append(
                ("rm:inputDataOfWorkflow", ttl_uri(workflow_uri))
            )
        if dataset.link_to_run:
            dataset_predicates.append(
                ("rm:usedByWorkflowRun", ttl_uri(run_uri))
            )
        add_resource(lines, ttl_uri(dataset.uri), dataset_predicates)

    # A publication links to the workflow, not to the run: rm:hasWorkflowRun is the
    # inverse of rm:workflow, so a publication holding a run would become that run's workflow.
    for publication_uri in publication_uris:
        add_resource(
            lines,
            ttl_uri(publication_uri),
            [("rm:usesWorkflow", ttl_uri(workflow_uri))],
        )

    add_resource(
        lines,
        ttl_uri(datetime_uri),
        [
            ("rdf:type", "vivo:DateTimeValue"),
            (
                "vivo:dateTime",
                ttl_literal(local_naive_iso(run_start), "xsd:dateTime"),
            ),
            (
                "vivo:dateTimePrecision",
                "vivo:yearMonthDayTimePrecision",
            ),
        ],
    )

    for stage in stage_records:
        stage_status_counts = Counter(
            task.status for task in stage["tasks"]
        )
        predicates: List[Tuple[str, str]] = [
            ("rdf:type", "rm:WorkflowProcessRun"),
            ("rdf:type", "vivo:InformationResource"),
            ("rdf:type", "prov:Activity"),
            ("rdfs:label", ttl_label(stage["run_label"])),
            ("dcterms:title", ttl_label(stage["run_label"])),
            ("rm:jobName", ttl_literal(stage["label"])),
            ("rm:runStatus", ttl_literal(stage["status"])),
            (
                "rm:taskCount",
                ttl_literal(len(stage["tasks"]), "xsd:integer"),
            ),
            (
                "rm:podCount",
                ttl_literal(len(stage["pod_names"]), "xsd:integer"),
            ),
            (
                "rm:succeededTaskCount",
                ttl_literal(
                    stage_status_counts["COMPLETED"]
                    + stage_status_counts["CACHED"],
                    "xsd:integer",
                ),
            ),
            (
                "rm:cachedTaskCount",
                ttl_literal(
                    stage_status_counts["CACHED"], "xsd:integer"
                ),
            ),
            (
                "rm:failedTaskCount",
                ttl_literal(
                    stage_status_counts["FAILED"]
                    + stage_status_counts["ERROR"],
                    "xsd:integer",
                ),
            ),
            (
                "rm:abortedTaskCount",
                ttl_literal(
                    stage_status_counts["ABORTED"], "xsd:integer"
                ),
            ),
            (
                "prov:startedAtTime",
                ttl_literal(
                    local_naive_iso(stage["start"]), "xsd:dateTime"
                ),
            ),
            (
                "prov:endedAtTime",
                ttl_literal(
                    local_naive_iso(stage["end"]), "xsd:dateTime"
                ),
            ),
            (
                "rm:durationSeconds",
                ttl_literal(
                    (
                        0
                        if (
                            stage["cached_only"]
                            and not stage["cached_origin_metrics"]
                        )
                        else seconds_between(stage["start"], stage["end"])
                    ),
                    "xsd:integer",
                ),
            ),
            (
                "rm:durationCalculationMethod",
                ttl_literal(
                    (
                        (
                            "Original execution window of the Kubernetes "
                            "pods that produced outputs reused from the "
                            "Nextflow cache."
                        )
                        if stage["cached_origin_metrics"]
                        else (
                            "No new execution time: all tasks in this stage "
                            "were reused from the Nextflow cache."
                        )
                        if stage["cached_only"]
                        else
                        "Wall-clock time from the earliest task submission "
                        "to the latest task completion or workflow "
                        "termination in this stage."
                    )
                ),
            ),
            ("rm:isWorkflowProcessOf", ttl_uri(run_uri)),
        ]
        for task_name in unique(
            canonical_task_name(task.name) for task in stage["tasks"]
        ):
            predicates.append(("rm:taskName", ttl_literal(task_name)))
        append_metric_predicates(
            predicates,
            stage["summary"],
            stage["methods"],
            energy_metric,
            carbon_info,
        )
        predicates.append(
            (
                "rm:parallelismNote",
                ttl_literal(
                    getattr(
                        args,
                        "parallelism_note",
                        "CPU time can exceed wall-clock duration when "
                        f"{engine_label} tasks execute concurrently.",
                    )
                ),
            )
        )
        add_resource(lines, ttl_uri(stage["uri"]), predicates)
        add_resource(
            lines,
            ttl_uri(stage["workflow_stage_uri"]),
            workflow_stage_predicates(
                stage["label"], workflow_uri, run_uri, stage["uri"]
            ),
        )

    expected_nodes = unique(
        metrics.node_name for metrics in pod_metrics.values()
    )
    missing_hardware = missing_node_metadata(expected_nodes, node_infos)
    audit = {
        "node_power": node_power,
        "workflow_name": args.workflow_name,
        "workflow_uri": workflow_uri,
        "run_uri": run_uri,
        "run_status": run_status,
        "run_start_utc": run_start.astimezone(timezone.utc).isoformat(),
        "run_end_utc": run_end.astimezone(timezone.utc).isoformat(),
        "run_start_berlin": run_start.astimezone(BERLIN_TZ).isoformat(),
        "run_end_berlin": run_end.astimezone(BERLIN_TZ).isoformat(),
        "duration_seconds": seconds_between(run_start, run_end),
        "resource_accounting_start_utc": (
            accounting_start.astimezone(timezone.utc).isoformat()
        ),
        "resource_accounting_end_utc": (
            accounting_end.astimezone(timezone.utc).isoformat()
        ),
        "task_count": len(tasks),
        "executed_task_count": sum(
            task.status != "CACHED" for task in tasks
        ),
        "cached_task_count": status_counts["CACHED"],
        "pod_count": len(all_pod_names),
        "include_cached_origin_metrics": (
            args.include_cached_origin_metrics
        ),
        "engine": {
            "label": engine_label,
            "session_id": log_metadata.get("session_id"),
            "run_name": log_metadata.get("run_name"),
            "version": (
                log_metadata.get("engine_version")
                or log_metadata.get("nextflow_version")
            ),
            "failure_reason": log_metadata.get("failure_reason"),
        },
        "nextflow": {
            "session_id": log_metadata.get("session_id"),
            "run_name": log_metadata.get("run_name"),
            "version": log_metadata.get("nextflow_version"),
            "failure_reason": log_metadata.get("failure_reason"),
        },
        "code": {
            "sha256": code_version,
            "git_commit": git_commit,
            "git_dirty": git_dirty,
            "uri": args.code_uri,
            "workflow_repository_uri": args.workflow_repo_url or None,
            "commit_uri": commit_url(args.workflow_repo_url, git_commit),
        },
        "input_datasets": [asdict(dataset) for dataset in input_datasets],
        "prometheus": {
            "url": args.prom_url,
            "energy_metric": energy_metric,
        },
        "carbon_intensity": asdict(carbon_info),
        "node_use": node_use,
        "summary": overall,
        "tasks": [
            {
                **asdict(task),
                "submit": task.submit.isoformat(),
                "start": task.start.isoformat() if task.start else None,
                "end": task.end.isoformat() if task.end else None,
            }
            for task in tasks
        ],
        "pod_metrics": {
            pod_name: asdict(metrics)
            for pod_name, metrics in pod_metrics.items()
        },
        "stages": [
            {
                "slug": stage["slug"],
                "label": stage["label"],
                "uri": stage["uri"],
                "status": stage["status"],
                "task_count": len(stage["tasks"]),
                "executed_task_count": sum(
                    task.status != "CACHED" for task in stage["tasks"]
                ),
                "cached_task_count": sum(
                    task.status == "CACHED" for task in stage["tasks"]
                ),
                "pod_count": len(stage["pod_names"]),
                "cached_only": stage["cached_only"],
                "cached_origin_metrics": stage["cached_origin_metrics"],
                "start": stage["start"].isoformat(),
                "end": stage["end"].isoformat(),
                "summary": stage["summary"],
            }
            for stage in stage_records
        ],
        "nodes": list(node_infos),
        "node_metadata": {
            "complete": not missing_hardware,
            "missing_by_node": missing_hardware,
            "required_fields": [
                label for _section, _key, label in REQUIRED_NODE_METADATA
            ],
        },
        "images": list(images),
    }
    return "\n".join(lines).rstrip() + "\n", audit


def build_args() -> argparse.Namespace:
    here = Path(__file__).resolve().parent
    repository_root = here.parent
    default_code_path = repository_root
    default_input_metadata_path = (
        repository_root / "config" / "input_datasets.json"
    )
    parser = argparse.ArgumentParser(
        description=(
            "Collect CPU, memory, Kepler energy, carbon, timing, Kubernetes, "
            "and Nextflow metadata for one Kubernetes run and write VIVO-ready TTL."
        )
    )
    parser.add_argument("--namespace", default=DEFAULT_NAMESPACE)
    parser.add_argument(
        "--run-identity-scope",
        default="",
        help=(
            "Public scope used at the start of generated run and datetime "
            "IRIs. Defaults to --namespace when omitted."
        ),
    )
    parser.add_argument("--driver-pod", default=DEFAULT_DRIVER_POD)
    parser.add_argument(
        "--trace-file",
        default=None,
        help="Local Nextflow trace TSV. By default the newest cluster trace is used.",
    )
    parser.add_argument(
        "--trace-remote",
        default=None,
        help="Explicit trace path inside nextflow-driver.",
    )
    parser.add_argument("--debug-log-file", default=None)
    parser.add_argument(
        "--debug-log-remote",
        default="/workspace/geoflow/.nextflow.log",
    )
    parser.add_argument("--console-log-file", default=None)
    parser.add_argument("--console-log-remote", default=None)
    parser.add_argument(
        "--trace-timezone",
        default="UTC",
        help="Timezone used by Nextflow trace and debug log timestamps.",
    )
    parser.add_argument("--workflow-name", default=DEFAULT_WORKFLOW_NAME)
    parser.add_argument(
        "--workflow-description",
        default="",
        help=(
            "Short description of what the workflow does, shown as the "
            "purpose of the workflow individual in VIVO."
        ),
    )
    parser.add_argument("--workflow-uri", default=DEFAULT_WORKFLOW_URI)
    parser.add_argument("--publication-uri", default=DEFAULT_PUBLICATION_URI)
    parser.add_argument("--code-path", default=str(default_code_path))
    parser.add_argument("--code-uri", default=DEFAULT_CODE_URI)
    parser.add_argument(
        "--container-image",
        action="append",
        default=None,
        help=(
            "Repeat for each declared workflow-task container image. These "
            "values are merged with Kubernetes-discovered image identities "
            "so deleted task pods do not cause provenance gaps."
        ),
    )
    parser.add_argument(
        "--git-commit",
        default=None,
        help=(
            "Explicit workflow commit for environments where the collected "
            "code directory does not contain .git metadata."
        ),
    )
    parser.add_argument(
        "--workflow-repo-url",
        default=DEFAULT_WORKFLOW_REPO_URL,
        help=(
            "Repository the workflow source belongs to; combined with the git "
            "commit to emit rm:codeCommitLink. Pass an empty string to omit."
        ),
    )
    parser.add_argument(
        "--input-metadata-file",
        default=str(default_input_metadata_path),
        help=(
            "JSON file describing InputDataset individuals linked to this "
            "workflow and run. Pass an empty string to omit input metadata."
        ),
    )
    parser.add_argument(
        "--workflow-trace-repository",
        default=DEFAULT_WORKFLOW_TRACE_REPOSITORY,
        help=(
            "General trace collection or repository linked from the workflow. "
            "Pass an empty string to omit."
        ),
    )
    parser.add_argument(
        "--run-trace-archive",
        default=DEFAULT_RUN_TRACE_ARCHIVE,
        help=(
            "Download URL for the exact trace bundle produced by this run. "
            "Pass an empty string to omit."
        ),
    )
    parser.add_argument(
        "--trace-archive",
        default=DEFAULT_TRACE_ARCHIVE,
        help=(
            "Deprecated compatibility setting used for both workflow and run "
            "when their specific trace URL is empty."
        ),
    )
    parser.add_argument("--trace-types", default=DEFAULT_TRACE_TYPES)
    parser.add_argument("--trace-data-format", default=DEFAULT_TRACE_DATA_FORMAT)
    parser.add_argument(
        "--responsible-researcher",
        action="append",
        default=None,
        help=(
            "Deprecated literal researcher name; ignored because VIVO expects "
            "a person URI. Use --responsible-researcher-uri."
        ),
    )
    parser.add_argument(
        "--responsible-researcher-uri",
        action="append",
        default=None,
        help="Repeat for each clickable VIVO researcher URI.",
    )
    parser.add_argument(
        "--subproject-uri",
        action="append",
        default=None,
        help="Repeat for each VIVO subproject URI.",
    )
    parser.add_argument(
        "--language-uri",
        action="append",
        default=None,
        help="Repeat for each non-workflow-engine language URI.",
    )
    parser.add_argument(
        "--application-domain-uri",
        default=DEFAULT_APPLICATION_DOMAIN_URI,
    )
    parser.add_argument("--run-operator-uri", default=DEFAULT_RUN_OPERATOR_URI)
    parser.add_argument("--cluster-uri", default=DEFAULT_CLUSTER_URI)
    parser.add_argument("--cluster-label", default="Fonda Cluster")
    parser.add_argument("--engine-uri", default=DEFAULT_ENGINE_URI)
    parser.add_argument("--backend-uri", default=DEFAULT_BACKEND_URI)
    parser.add_argument("--prom-url", default=PROM_URL_DEFAULT)
    parser.add_argument(
        "--node-use-max-other-cpus",
        type=float,
        default=NODE_USE_MAX_OTHER_CPUS_DEFAULT,
        help=(
            "A run is published as 'exclusive' (rm:nodeUse) when other "
            "workloads kept at most this many CPUs busy on its nodes, on "
            "average during the run. Node daemons are not counted."
        ),
    )
    parser.add_argument(
        "--carbon-intensity",
        type=float,
        default=CARBON_INTENSITY_DEFAULT,
        help="kg CO2e per kWh; default matches the earlier FORCE collector.",
    )
    parser.add_argument(
        "--carbon-intensity-source",
        choices=(
            "fixed",
            "electricity-maps",
            "electricity-maps-latest",
            "co2map",
        ),
        default="fixed",
        help=(
            "Use the configured fixed factor, historical Electricity Maps, "
            "the latest Electricity Maps value as a collection-time proxy, "
            "or CO2Map.de data aligned to the resource-accounting window."
        ),
    )
    parser.add_argument(
        "--electricity-maps-api-token-env",
        default="ELECTRICITY_MAPS_API_TOKEN",
        help="Environment variable containing the Electricity Maps API token.",
    )
    parser.add_argument("--electricity-maps-zone", default="DE")
    parser.add_argument(
        "--electricity-maps-api-url",
        default=(
            "https://api.electricitymaps.com/v4/"
            "carbon-intensity/past-range"
        ),
    )
    parser.add_argument(
        "--electricity-maps-latest-api-url",
        default=(
            "https://api.electricitymaps.com/v4/"
            "carbon-intensity/latest"
        ),
    )
    parser.add_argument(
        "--electricity-maps-disable-estimations",
        action="store_true",
        help="Reject estimated Electricity Maps carbon-intensity points.",
    )
    parser.add_argument(
        "--co2map-api-url",
        default="https://api.co2map.de",
    )
    parser.add_argument("--co2map-state", default="DE")
    parser.add_argument("--co2map-country", default="DE")
    parser.add_argument(
        "--co2map-data-status",
        choices=("preliminary", "historical"),
        default="preliminary",
        help=(
            "Use preliminary near-real-time data or finalized historical "
            "CO2Map.de data."
        ),
    )
    parser.add_argument("--memory-step-seconds", type=int, default=15)
    parser.add_argument("--metrics-padding-seconds", type=int, default=30)
    parser.add_argument(
        "--include-cached-origin-metrics",
        action="store_true",
        help=(
            "Attribute metrics from the original pods referenced by CACHED "
            "trace rows. Use this for a composite Nextflow session view."
        ),
    )
    parser.add_argument("--base-uri", default=BASE_URI_DEFAULT)
    parser.add_argument("--ontology-uri", default=ONTOLOGY_URI_DEFAULT)
    parser.add_argument(
        "--output-dir",
        default=str(repository_root / "metadata" / "generated"),
    )
    parser.add_argument("--output-file", default=None)
    parser.add_argument("--output-stamp", default=None)
    parser.add_argument(
        "--allow-active-run",
        action="store_true",
        help="Allow collection while the trace still describes an active run.",
    )
    parser.add_argument(
        "--require-succeeded",
        action="store_true",
        help=(
            "Refuse to emit metadata unless the selected run has status "
            "Succeeded. This also rejects cached/retry warnings when a "
            "strict clean execution is required."
        ),
    )
    parser.add_argument(
        "--allow-missing-metrics",
        action="store_true",
        help="Write structural TTL even when Prometheus has no pod metrics.",
    )
    return parser.parse_args()


def resolve_output_path(
    args: argparse.Namespace,
    run_start: datetime,
) -> Path:
    if args.output_file:
        output_path = Path(args.output_file).expanduser().resolve()
    else:
        output_dir = Path(args.output_dir).expanduser().resolve()
        output_dir.mkdir(parents=True, exist_ok=True)
        stamp = args.output_stamp or run_start.astimezone(BERLIN_TZ).strftime(
            "%d%m%Y_%H%M"
        )
        output_path = output_dir / f"{DEFAULT_OUTPUT_STEM}-{stamp}.ttl"

    output_path.parent.mkdir(parents=True, exist_ok=True)
    return output_path


def main() -> None:
    args = build_args()
    if (
        args.workflow_name == DEFAULT_WORKFLOW_NAME
        or args.workflow_uri == DEFAULT_WORKFLOW_URI
    ):
        raise RuntimeError(
            "Pass explicit --workflow-name and --workflow-uri values; the "
            "generic example identity must never be written to VIVO metadata."
        )
    trace_tz = ZoneInfo(args.trace_timezone)
    input_datasets = load_input_datasets(args.input_metadata_file)

    trace_remote = args.trace_remote
    if not args.trace_file and not trace_remote:
        trace_remote = detect_latest_remote_trace(
            args.namespace, args.driver_pod
        )
    trace_text = load_text(
        args.trace_file,
        trace_remote,
        args.namespace,
        args.driver_pod,
        required=True,
    )
    tasks = parse_trace(trace_text, trace_tz)

    debug_log = load_text(
        args.debug_log_file,
        args.debug_log_remote,
        args.namespace,
        args.driver_pod,
        required=False,
    )
    console_log = load_text(
        args.console_log_file,
        args.console_log_remote,
        args.namespace,
        args.driver_pod,
        required=False,
    )
    trace_start = min(task.submit for task in tasks)
    log_metadata = parse_log_metadata(
        debug_log,
        console_log,
        trace_start.year,
        trace_tz,
    )
    normalize_finished_tasks(tasks, bool(log_metadata["finished"]))

    run_start = log_metadata["start"] or trace_start
    derived_task_ends = [task.end for task in tasks if task.end is not None]
    trace_end = max(
        derived_task_ends + [max(task.submit for task in tasks)]
    )
    run_end = log_metadata["end"] or trace_end
    if run_end < run_start:
        raise RuntimeError("Derived run end precedes run start")
    for task in tasks:
        if task.end is None and log_metadata["finished"]:
            task.end = run_end

    run_status = derive_status(
        tasks,
        bool(log_metadata["finished"]),
        bool(log_metadata["successful"]),
    )
    if run_status == "Running" and not args.allow_active_run:
        raise RuntimeError(
            "The selected trace still describes an active run. Wait for "
            "Nextflow to finish, or pass --allow-active-run explicitly."
        )
    validate_required_success(tasks, run_status, args.require_succeeded)

    ensure_prometheus_reachable(args.prom_url)
    metric_names = prometheus_metric_names(args.prom_url)
    energy_metric = find_energy_metric(metric_names)
    accounting_start, accounting_end = resource_accounting_window(
        tasks,
        run_start,
        run_end,
        args.include_cached_origin_metrics,
    )
    metric_start = accounting_start - timedelta(
        seconds=args.metrics_padding_seconds
    )
    metric_end = accounting_end + timedelta(
        seconds=args.metrics_padding_seconds
    )
    carbon_info = resolve_carbon_intensity(
        args,
        accounting_start,
        accounting_end,
    )
    pod_metrics = collect_pod_metrics(
        args, tasks, metric_start, metric_end, energy_metric
    )

    any_metrics = any(
        metrics.cpu_seconds is not None
        or metrics.energy_joules is not None
        or bool(metrics.memory_series)
        for metrics in pod_metrics.values()
    )
    if not any_metrics and not args.allow_missing_metrics:
        raise RuntimeError(
            "Prometheus returned no CPU, memory, or energy measurements for "
            "the pods in this trace. Check the port-forward and retention, or "
            "pass --allow-missing-metrics to emit structural metadata only."
        )

    code_path = Path(args.code_path).expanduser().resolve()
    code_version = sha256_source(code_path)
    git_commit, git_dirty = git_metadata(code_path)
    if args.git_commit:
        explicit_commit = args.git_commit.strip().lower()
        if not re.fullmatch(r"[0-9a-f]{40}", explicit_commit):
            raise RuntimeError("--git-commit must be a 40-character SHA-1")
        git_commit = explicit_commit
    observed_images = unique(
        image
        for metrics in pod_metrics.values()
        for image in metrics.images
    )
    images = select_container_images(
        args.container_image or [],
        observed_images,
        images_from_code(code_path),
    )
    node_names = unique(
        metrics.node_name for metrics in pod_metrics.values()
    )
    node_infos = collect_node_info(node_names, args.prom_url)
    missing_hardware = missing_node_metadata(node_names, node_infos)
    if missing_hardware:
        details = "; ".join(
            f"{node}: {', '.join(fields)}"
            for node, fields in missing_hardware.items()
        )
        print(
            "WARNING: publication is missing hardware metadata: " + details,
            file=sys.stderr,
        )
    node_use: Optional[Dict[str, Any]] = None
    # FONDA 2026-10-20: the Nextflow driver's pod counts as part of the run (debug log "Process: PID@POD").
    args.detected_driver_pod = driver_pod_from_log(debug_log)
    try:
        node_use = kubernetes_node_use(
            args.prom_url,
            node_names,
            [*pod_metrics.keys(), args.driver_pod, args.detected_driver_pod],
            metric_start,
            metric_end,
            args.node_use_max_other_cpus,
        )
    except Exception as exc:
        print(
            f"WARNING: could not determine the node use of the run: {exc}",
            file=sys.stderr,
        )
    stages = group_tasks(tasks)
    responsible_researchers = (
        args.responsible_researcher
        if args.responsible_researcher is not None
        else DEFAULT_RESPONSIBLE_RESEARCHERS
    )
    responsible_researcher_uris = (
        args.responsible_researcher_uri
        if args.responsible_researcher_uri is not None
        else DEFAULT_RESPONSIBLE_RESEARCHER_URIS
    )
    subproject_uris = (
        args.subproject_uri
        if args.subproject_uri is not None
        else DEFAULT_SUBPROJECT_URIS
    )
    language_uris = (
        args.language_uri
        if args.language_uri is not None
        else DEFAULT_LANGUAGE_URIS
    )

    ttl_text, audit = build_ttl(
        args=args,
        tasks=tasks,
        stages=stages,
        pod_metrics=pod_metrics,
        run_start=run_start,
        run_end=run_end,
        run_status=run_status,
        log_metadata=log_metadata,
        code_version=code_version,
        git_commit=git_commit,
        git_dirty=git_dirty,
        energy_metric=energy_metric,
        carbon_info=carbon_info,
        node_infos=node_infos,
        images=images,
        responsible_researchers=responsible_researchers,
        responsible_researcher_uris=responsible_researcher_uris,
        subproject_uris=subproject_uris,
        language_uris=language_uris,
        input_datasets=input_datasets,
        node_use=node_use,
    )

    output_path = resolve_output_path(args, run_start)
    output_path.write_text(ttl_text, encoding="utf-8")
    audit_path = output_path.with_suffix(".metrics.json")
    audit_path.write_text(
        json.dumps(audit, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    manifest_path = output_path.parent / "VIVO_UPLOAD_FILES.txt"
    manifest_path.write_text(
        f"TTL files ready to upload to VIVO:\n{output_path}\n",
        encoding="utf-8",
    )

    summary = audit["summary"]
    print(f"Wrote TTL: {output_path}")
    print(f"Wrote audit JSON: {audit_path}")
    print(f"Wrote manifest: {manifest_path}")
    print(f"selected_trace={args.trace_file or trace_remote}")
    print(f"run_status={run_status}")
    print(f"task_count={len(tasks)}")
    print(f"pod_count={len(pod_metrics)}")
    print(f"workflow_start={run_start.isoformat()}")
    print(f"workflow_end={run_end.isoformat()}")
    print(f"cpu_seconds={summary['cpu_seconds']}")
    print(f"memory_avg_gb={summary['memory_avg_gb']}")
    print(f"memory_peak_gb={summary['memory_peak_gb']}")
    print(f"energy_metric={energy_metric or 'none'}")
    print(f"energy_kwh={summary['energy_kwh']}")
    print(f"carbon_intensity_source={carbon_info.source}")
    print(
        "carbon_intensity_kg_per_kwh="
        f"{carbon_info.kg_per_kwh}"
    )
    print(f"carbon_kg_co2e={summary['carbon_kg']}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("Interrupted", file=sys.stderr)
        sys.exit(130)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
