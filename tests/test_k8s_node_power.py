"""Synthetic Prometheus and Electricity Maps only: the add-on for single-node Kubernetes runs."""
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
import io
import json
from pathlib import Path
import re
import sys
import tempfile
import threading
import unittest
from unittest import mock
import urllib.parse

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "collector"))
import collect_k8s_node_power as addon  # noqa: E402

UTC = timezone.utc
NODE = "hu-worker-c39"
# run 2026-10-20 15:10:00-15:13:00 Berlin = 13:10-13:13 UTC
START = datetime(2026, 10, 20, 13, 10, tzinfo=UTC).timestamp()
END = START + 180
IDLE, BUSY = 120.0, 220.0


def power(t):
    return BUSY if START <= t < END else IDLE


def energy(a, b):
    """Integral of power() over [a, b] in joules."""
    inside = max(0.0, min(b, END) - max(a, START))
    return IDLE * (b - a) + (BUSY - IDLE) * inside


class FakeProm(BaseHTTPRequestHandler):
    busy_cpus = 0.3

    def log_message(self, *args):
        pass

    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        q = dict(urllib.parse.parse_qsl(url.query))
        query = q["query"]
        assert f'instance="{NODE}"' in query or f'node="{NODE}"' in query, query
        result = []
        if url.path == "/api/v1/query":
            at = float(q["time"])
            if query.startswith("count_over_time"):
                result = [{"metric": {}, "value": [at, "20"]}]
            elif "increase(" in query:
                seconds = float(re.search(r"\[(\d+)s\]", query).group(1))
                result = [{"metric": {}, "value": [at, str(energy(at - seconds, at))]}]
            elif "container_cpu_usage_seconds_total" in query:
                result = [{"metric": {}, "value": [at, str(self.busy_cpus)]}]
            elif "rate(" in query:
                window = float(re.search(r"\[(\d+)s\]", query).group(1))
                result = [{"metric": {}, "value": [at, str(energy(at - window, at) / window)]}]
        else:
            start, end = float(q["start"]), float(q["end"])
            step = float(q["step"].rstrip("s"))
            window = float(re.search(r"\[(\d+)s\]", query).group(1))
            values, t = [], start
            while t <= end + 1e-9:
                values.append([t, str(energy(t - window, t) / window)])
                t += step
            result = [{"metric": {}, "values": values}]
        body = json.dumps({"status": "success", "data": {"resultType": "vector", "result": result}}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body)


TTL = f"""@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix prov: <http://www.w3.org/ns/prov#> .
@prefix rm: <http://example.org/ontology/run-metadata#> .

<http://example.org/vivo-import/run-metadata/run/yagmur-x>
  rdf:type rm:RunMetadata ;
  prov:startedAtTime "2026-10-20T15:10:00"^^xsd:dateTime ;
  prov:endedAtTime "2026-10-20T15:13:00"^^xsd:dateTime ;
  rm:durationSeconds "180"^^xsd:integer ;
  rm:energyKWh "0.0012"^^xsd:double ;
  rm:carbonEmissionKgCO2e "0.00042"^^xsd:double ;
  rm:carbonIntensityAssumptionKgCO2ePerKWh "0.35"^^xsd:double ;
  rm:carbonCalculationMethod "Latest value \\"proxy\\" at collection." ;
  rm:energyCalculationMethod "Sum of Kepler pod energy." ;
  rm:energyMeasurementCoverage "14.3% (4 of 28 pods)" ;
  rm:carbonIntensityWindowStart "2026-10-20T14:00:00Z"^^xsd:dateTime ;
  rm:nodeUse "exclusive (other workloads used 0.03 CPUs on average on the run's 1 node)" ;
  rm:executionHost "{NODE}" .

<http://example.org/vivo-import/run-metadata/process/x-fastp>
  rdf:type rm:WorkflowProcessRun ;
  rm:energyKWh "0.0001"^^xsd:double .
"""


def history():
    first = datetime(2026, 10, 19, 15, tzinfo=UTC)
    points = []
    for i in range(24):
        hour = first + timedelta(hours=i)
        points.append(dict(datetime=hour.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
                           g_per_kwh=300.0 + i, estimated=i == 23))
    return "https://api.electricitymaps.com/v4/carbon-intensity/history?zone=DE", points


class AddonTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = HTTPServer(("127.0.0.1", 0), FakeProm)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        cls.prom = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.ttl = self.dir / "RANGELAND-1NODE-01-20261020T132500Z.ttl"
        self.ttl.write_text(TTL)
        FakeProm.busy_cpus = 0.3

    def tearDown(self):
        self.tmp.cleanup()

    def run_addon(self, now=END + 3600, ttl=None, hist=history, quarters=None):
        args = ["--ttl", str(ttl or self.ttl), "--prom-url", self.prom, "--out-dir", str(self.dir),
                "--token", "x", "--now", str(now)]
        out, err = io.StringIO(), io.StringIO()

        def fetch(token, granularity="hourly", start=None, end=None):
            if granularity == "hourly":
                return hist()
            if quarters is None:
                raise ValueError("no 15-minute data for this account")
            return quarters()
        with mock.patch.object(addon, "fetch_history", side_effect=fetch), \
                mock.patch("sys.stdout", out), mock.patch("sys.stderr", err):
            code = addon.main(args)
        stem = self.ttl.name[:-4]
        files = {kind: (self.dir / f"{stem}-node-power_{kind}.ttl") for kind in ("ADD", "REMOVE")}
        return code, out.getvalue(), err.getvalue(), files

    def test_exclusive_run_gets_whole_node_values(self):
        code, out, err, files = self.run_addon()
        self.assertEqual(code, 0, err)
        add, remove = files["ADD"].read_text(), files["REMOVE"].read_text()
        summary = json.loads((self.dir / (self.ttl.name[:-4] + "-node-power.json")).read_text())
        self.assertAlmostEqual(summary["node_energy_kwh"], 220 * 180 / 3.6e6, places=9)
        self.assertEqual(summary["idle_w"], 120.0)
        self.assertAlmostEqual(summary["above_idle_kwh"], 100 * 180 / 3.6e6, places=9)
        self.assertEqual(len(summary["quiet_windows"]), 2)
        self.assertIn("rm:nodeIdlePowerW \"120.0\"^^xsd:double", add)
        self.assertIn('rm:idlePowerMethod "Idle power of node hu-worker-c39: 120.0 W, the mean power of the node', add)
        self.assertIn('in two quiet windows of 10 minutes, 60 s before and after the run: 14:59-15:09 Berlin time 120.0 W (0.30 CPUs busy on average); 15:14-15:24', add)
        self.assertIn('cores in deep sleep 93% and the package 44% of the time', add)
        self.assertIn('so it includes the energy needed to keep the node awake for the job."', add)
        self.assertIn('rm:energyMeasurementCoverage "100% of the node (whole node, measured)"', add)
        self.assertIn("rm:nodePowerReadings", add)
        self.assertRegex(add, r'rm:nodePowerReadings "0\.0 \d+; 30\.0 \d+;')
        self.assertIn("rm:gridCarbonIntensityHours", add)
        self.assertIn("2026-10-20T13:00Z 322.0", add)
        self.assertIn("2026-10-20T14:00Z 323.0*", add)
        # time-matched: the whole run lies in the 13:00 UTC hour (322 g/kWh)
        self.assertIn('rm:carbonIntensityAssumptionKgCO2ePerKWh "0.322"^^xsd:double', add)
        self.assertIn('rm:carbonIntensityWindowStart "2026-10-20T13:00:00Z"^^xsd:dateTime', add)
        self.assertIn("It replaces the sum of the run's pods' Kepler shares (0.001200 kWh)", add)
        # every replaced value is removed first, verbatim; the stage's energy stays
        for line in ('rm:energyKWh "0.0012"^^xsd:double', 'rm:carbonEmissionKgCO2e "0.00042"^^xsd:double',
                     'rm:energyMeasurementCoverage "14.3% (4 of 28 pods)"',
                     'rm:carbonCalculationMethod "Latest value \\"proxy\\" at collection."',
                     'rm:carbonIntensityWindowStart "2026-10-20T14:00:00Z"^^xsd:dateTime'):
            self.assertIn(line, remove)
        self.assertNotIn("0.0001", remove)
        self.assertNotIn("rm:executionHost", remove)
        for text in (add, remove):
            self.assertTrue(text.rstrip().endswith("."))
            self.assertIn("@prefix rm:", text)
            self.assertEqual(text.count("<http://example.org/vivo-import/run-metadata/run/yagmur-x>"), 1)

    def test_fifteen_minute_data_is_used_for_carbon(self):
        def quarters():
            first = datetime(2026, 10, 20, 12, tzinfo=UTC)
            return ("https://api.electricitymaps.com/v4/carbon-intensity/past-range?zone=DE",
                    [dict(datetime=(first + timedelta(minutes=15 * i)).strftime("%Y-%m-%dT%H:%M:%S.000Z"),
                          g_per_kwh=250.0, estimated=False, seconds=900) for i in range(16)])
        code, _, err, files = self.run_addon(quarters=quarters)
        self.assertEqual(code, 0, err)
        add = files["ADD"].read_text()
        self.assertIn('rm:carbonIntensityTemporalGranularity "15 minutes"', add)
        self.assertIn("Electricity Maps 15-minute history", add)
        self.assertIn('rm:carbonIntensityAssumptionKgCO2ePerKWh "0.25"^^xsd:double', add)
        self.assertIn('rm:carbonIntensityWindowStart "2026-10-20T13:00:00Z"^^xsd:dateTime', add)
        self.assertIn('rm:carbonIntensityWindowEnd "2026-10-20T13:15:00Z"^^xsd:dateTime', add)
        self.assertIn("in the quarter-hours the run used", add)
        # the hours around the run for the run page still come from the hourly history
        self.assertIn("2026-10-20T13:00Z 322.0", add)

    def test_readings_are_centred_and_reach_the_run_end(self):
        ttl = self.dir / "RANGELAND-1NODE-01-20261020T132500Z.ttl"
        ttl.write_text(TTL.replace("15:13:00", "15:13:35").replace('"180"^^xsd:integer', '"215"^^xsd:integer'))
        with mock.patch.object(sys.modules[__name__], "END", START + 215):
            code, _, err, files = self.run_addon(ttl=ttl)
        self.assertEqual(code, 0, err)
        text = re.search(r'rm:nodePowerReadings "([^"]+)"', files["ADD"].read_text()).group(1)
        points = [tuple(map(float, part.split())) for part in text.split("; ")]
        self.assertEqual(points[0][0], 0.0)
        self.assertEqual(points[-1][0], 215.0)
        self.assertEqual([o for o, _ in points[:-1]], [30.0 * i for i in range(len(points) - 1)])
        # centred 61 s windows: half idle, half busy at the start; busy 30 s later
        self.assertEqual(points[0][1], 170.0)
        self.assertEqual(points[1][1], 219.0)  # (0.5 s x 120 W + 60.5 s x 220 W) / 61 s
        self.assertIn("centred on its time", files["ADD"].read_text())

    def test_second_pass_removes_the_first_pass_values(self):
        code, _, err, files = self.run_addon()
        self.assertEqual(code, 0, err)
        first_add = files["ADD"].read_text()
        FakeProm.busy_cpus = 0.4
        code, out, err, files = self.run_addon()
        self.assertEqual(code, 0, err)
        remove = files["REMOVE"].read_text()
        self.assertIn("Earlier files of this run kept as", out)
        self.assertEqual(len(list(self.dir.glob("*-node-power_ADD.ttl.prev-*"))), 1)
        self.assertIn('rm:nodeIdlePowerW "120.0"^^xsd:double', remove)
        self.assertIn('rm:energyKWh "0.0012"^^xsd:double', remove)
        self.assertEqual(remove.count('rm:energyMeasurementCoverage "100% of the node (whole node, measured)"'), 1)
        self.assertNotEqual(first_add, files["ADD"].read_text())
        for line in first_add.splitlines():
            if line.startswith("  rm:"):
                self.assertIn(line.strip()[:-2], remove)

    def test_files_parse_as_turtle(self):
        try:
            import rdflib
        except ImportError:
            self.skipTest("rdflib not installed")
        code, _, err, files = self.run_addon()
        self.assertEqual(code, 0, err)
        graph = rdflib.Graph().parse(data=files["ADD"].read_text(), format="turtle")
        self.assertGreater(len(graph), 15)
        removed = rdflib.Graph().parse(data=files["REMOVE"].read_text(), format="turtle")
        original = rdflib.Graph().parse(data=TTL, format="turtle")
        self.assertTrue(all(t in original for t in removed))

    def test_only_before_window_soon_after_the_run(self):
        code, _, err, files = self.run_addon(now=END + 120)
        self.assertEqual(code, 0, err)
        summary = json.loads((self.dir / (self.ttl.name[:-4] + "-node-power.json")).read_text())
        self.assertEqual(len(summary["quiet_windows"]), 1)
        self.assertIn("only the window before the run", err)
        self.assertIn("in one quiet window of 10 minutes, 60 s before the run: ", files["ADD"].read_text())

    def test_busy_quiet_window_is_reported(self):
        FakeProm.busy_cpus = 5.0
        code, _, err, files = self.run_addon()
        self.assertEqual(code, 0)
        self.assertIn("busy CPUs in the quiet window", err)
        self.assertIn("the idle power may be too high", files["ADD"].read_text())

    def test_without_grid_history_the_old_intensity_is_applied(self):
        def broken():
            raise ValueError("No hourly Electricity Maps data")
        code, out, err, files = self.run_addon(hist=broken)
        self.assertEqual(code, 0, err)
        add = files["ADD"].read_text()
        self.assertNotIn("gridCarbonIntensityHours", add)
        self.assertIn(f'rm:carbonEmissionKgCO2e "{repr(220 * 180 / 3.6e6 * 0.35)}"^^xsd:double', add)
        self.assertIn("Applied to the whole-node energy", add)
        self.assertNotIn("carbonIntensityWindowStart", files["REMOVE"].read_text())

    def test_shared_or_multi_node_runs_are_refused(self):
        shared = self.dir / "shared.ttl"
        shared.write_text(TTL.replace('rm:nodeUse "exclusive', 'rm:nodeUse "non-exclusive'))
        code, _, err, _ = self.run_addon(ttl=shared)
        self.assertEqual(code, 2)
        self.assertIn("not published as exclusive", err)
        two = self.dir / "two.ttl"
        two.write_text(TTL.replace(f'rm:executionHost "{NODE}" .',
                                   f'rm:executionHost "{NODE}" ;\n  rm:executionHost "hu-worker-c41" .'))
        code, _, err, _ = self.run_addon(ttl=two)
        self.assertEqual(code, 2)
        self.assertIn("this add-on is for one node", err)


if __name__ == "__main__":
    unittest.main()
