"""Whole-node energy, idle power, power readings and grid carbon of an exclusive single-node run
(node_power_apply in collect_nextflow_run_metadata.py). Simulated Prometheus and Electricity Maps."""
import argparse
from datetime import datetime, timedelta, timezone
import io
import os
import re
import unittest
from unittest import mock
from urllib.parse import urlencode

from collector import collect_nextflow_run_metadata as collector
from collector.collect_nextflow_run_metadata import (CarbonIntensityInfo, PodMetrics, TaskRecord, build_ttl,
                                                     node_power_apply, node_use_text, ttl_literal)

UTC = timezone.utc
NODE = "hu-worker-c39"
START = datetime(2026, 10, 20, 13, 36, 18, tzinfo=UTC)
END = START + timedelta(seconds=215)
S, E = START.timestamp(), END.timestamp()
IDLE, BUSY = 121.8, 175.0


def joules(a, b):
    inside = max(0.0, min(b, E) - max(a, S))
    return IDLE * (b - a) + (BUSY - IDLE) * inside


def history(zone="DE", rows=None):
    first = datetime(2026, 10, 19, 14, tzinfo=UTC)
    rows = rows if rows is not None else [
        {"datetime": (first + timedelta(hours=i)).strftime("%Y-%m-%dT%H:%M:%S.000Z"), "carbonIntensity": 300 + i,
         "isEstimated": i == 23, "emissionFactorType": "lifecycle", "flowTraced": True} for i in range(24)]
    return {"zone": zone, "temporalGranularity": "hourly", "history": rows}


class FakeServices:
    def __init__(self, busy=0.3, em=history):
        self.busy, self.em, self.calls = busy, em, []

    def __call__(self, url, params=None, headers=None):
        self.calls.append((url, dict(params or {})))
        if "electricitymaps" in url:
            if self.em is None:
                raise RuntimeError("HTTP 401 returned by Electricity Maps")
            assert headers == {"auth-token": "secret"}
            return self.em()
        query = params["query"]
        assert f'instance="{NODE}"' in query or f'node="{NODE}"' in query, query
        if url.endswith("/query_range"):
            start, end, step = float(params["start"]), float(params["end"]), float(params["step"][:-1])
            window = float(re.search(r"\[(\d+)s\]", query).group(1))
            values, t = [], start
            while t <= end + 1e-9:
                values.append([t, str(joules(t - window, t) / window)])
                t += step
            return {"status": "success", "data": {"result": [{"metric": {}, "values": values}]}}
        at = float(params["time"])
        window = float(re.search(r"\[(\d+)s\]", query).group(1))
        if query.startswith("count_over_time"):
            value = 20
        elif "container_cpu_usage_seconds_total" in query:
            value = self.busy
        elif "increase(" in query:
            value = joules(at - window, at)
        else:
            value = joules(at - window, at) / window
        return {"status": "success", "data": {"result": [{"metric": {}, "value": [at, str(value)]}]}}


def args(**extra):
    base = dict(prom_url="http://prometheus:9090", electricity_maps_api_token_env="ELECTRICITY_MAPS_API_TOKEN",
                electricity_maps_zone="DE")
    base.update(extra)
    return argparse.Namespace(**base)


def predicates():
    return [("rdf:type", "rm:RunMetadata"), ("rm:energyKWh", ttl_literal(5.481666666666666e-06)),
            ("rm:carbonEmissionKgCO2e", ttl_literal(1.97e-06)),
            ("rm:carbonIntensityAssumptionKgCO2ePerKWh", ttl_literal(0.361)),
            ("rm:carbonCalculationMethod", ttl_literal('Latest "proxy" value.')),
            ("rm:energyMeasurementCoverage", ttl_literal("14.3% (4 of 28 pods)")),
            ("rm:executionHost", ttl_literal(NODE))]


EXCLUSIVE = {"exclusive": True, "text": node_use_text(True, 0.0, 1)}


class NodePowerTests(unittest.TestCase):
    def apply(self, preds, nodes=(NODE,), use=EXCLUSIVE, now=E + 3600, services=None, env=None):
        services = services or FakeServices()
        environment = {"ELECTRICITY_MAPS_API_TOKEN": "secret"} if env is None else env
        with mock.patch.object(collector, "http_get_json", side_effect=services), \
                mock.patch.dict(os.environ, environment, clear=False), \
                mock.patch("sys.stdout", io.StringIO()), mock.patch("sys.stderr", io.StringIO()) as err:
            summary = node_power_apply(args(), preds, list(nodes), use, START, END, now=now)
        return summary, dict(preds), err.getvalue(), services

    def test_exclusive_single_node_run(self):
        preds = predicates()
        summary, values, err, _ = self.apply(preds)
        self.assertTrue(summary["applied"], err)
        self.assertAlmostEqual(summary["node_energy_kwh"], joules(S, E) / 3.6e6, places=9)
        self.assertEqual(summary["idle_w"], 121.8)
        self.assertAlmostEqual(summary["above_idle_kwh"], (BUSY - IDLE) * 215 / 3.6e6, places=9)
        self.assertEqual(len(summary["quiet_windows"]), 2)
        self.assertEqual(values["rm:energyMeasurementCoverage"], '"100% of the node (whole node, measured)"')
        self.assertEqual(values["rm:nodeIdlePowerW"], '"121.8"^^xsd:double')
        readings = re.search(r'"([^"]+)"', values["rm:nodePowerReadings"]).group(1).split("; ")
        self.assertTrue(readings[0].startswith("0.0 "))
        self.assertTrue(readings[-1].startswith("215.0 "))
        self.assertIn("2026-10-20T13:00Z 323.0", values["rm:gridCarbonIntensityHours"])
        self.assertIn("2026-10-20T13:00:00Z", values["rm:carbonIntensityWindowStart"])
        self.assertEqual(values["rm:carbonIntensityAssumptionKgCO2ePerKWh"], ttl_literal(0.323))
        self.assertIn("It replaces the sum of the run's pods' Kepler shares (0.000005 kWh)",
                      values["rm:energyCalculationMethod"])
        # each property once, the host untouched
        self.assertEqual(len([p for p, _ in preds if p == "rm:energyKWh"]), 1)
        self.assertIn(("rm:executionHost", ttl_literal(NODE)), preds)

    def test_runs_on_several_or_shared_nodes_are_unchanged(self):
        for nodes, use in (((NODE, "hu-worker-c41"), EXCLUSIVE),
                           ((NODE,), {"exclusive": False, "text": "non-exclusive (...)"}), ((NODE,), None)):
            preds = predicates()
            summary, _, _, services = self.apply(preds, nodes=nodes, use=use)
            self.assertFalse(summary["applied"])
            self.assertEqual(preds, predicates())
            self.assertEqual(services.calls, [])

    def test_switched_off(self):
        preds = predicates()
        summary, _, _, services = self.apply(preds, env={"FONDA_NODE_POWER": "0"})
        self.assertFalse(summary["applied"])
        self.assertEqual(services.calls, [])

    def test_prometheus_failure_keeps_the_pod_energy(self):
        preds = predicates()

        def broken(url, params=None, headers=None):
            raise RuntimeError("HTTP 503 returned by http://prometheus:9090")
        with mock.patch.object(collector, "http_get_json", side_effect=broken), \
                mock.patch("sys.stderr", io.StringIO()) as err:
            summary = node_power_apply(args(), preds, [NODE], EXCLUSIVE, START, END, now=E + 3600)
        self.assertFalse(summary["applied"])
        self.assertEqual(preds, predicates())
        self.assertIn("node power not added", err.getvalue())

    def test_without_grid_history_the_intensity_is_applied_to_the_node_energy(self):
        preds = predicates()
        summary, values, err, _ = self.apply(preds, services=FakeServices(em=None))
        self.assertTrue(summary["applied"])
        self.assertNotIn("rm:gridCarbonIntensityHours", values)
        self.assertEqual(values["rm:carbonEmissionKgCO2e"], ttl_literal(summary["node_energy_kwh"] * 0.361))
        self.assertIn('Latest \\"proxy\\" value. Applied to the whole-node energy', values["rm:carbonCalculationMethod"])
        self.assertIn("carbon not time-matched", err)

    def test_soon_after_the_run_and_busy_window(self):
        preds = predicates()
        summary, values, err, _ = self.apply(preds, now=E + 120, services=FakeServices(busy=5.0))
        self.assertEqual(len(summary["quiet_windows"]), 1)
        self.assertIn("only the window before the run", err)
        self.assertIn("the idle power may be too high", values["rm:nodeConditionsMethod"])


class TurtleTests(unittest.TestCase):
    def test_build_ttl_publishes_the_node_power(self):
        task = TaskRecord(task_id="1", hash_value="aa/1", pod_name="nf-test", name="test", status="COMPLETED",
                          exit_code=0, submit=START, duration_seconds=2.0, realtime_seconds=1.0, end=END)
        namespace = argparse.Namespace(
            application_domain_uri="", backend_uri="", base_uri="http://example.org/vivo-import/run-metadata/",
            cluster_label="Fonda Cluster", cluster_uri="https://example.org/cluster", code_uri="",
            engine_uri="", include_cached_origin_metrics=False, namespace="test",
            ontology_uri="http://example.org/ontology/run-metadata#", prom_url="http://prometheus:9090",
            publication_uri="", run_identity_scope="fonda", run_operator_uri="", trace_archive="",
            workflow_trace_repository="", run_trace_archive="", trace_data_format="TSV",
            trace_types="Nextflow trace", workflow_name="Node power test", workflow_repo_url="",
            workflow_uri="https://example.org/workflow/test",
            electricity_maps_api_token_env="ELECTRICITY_MAPS_API_TOKEN", electricity_maps_zone="DE")
        with mock.patch.object(collector, "http_get_json", side_effect=FakeServices()), \
                mock.patch.dict(os.environ, {"ELECTRICITY_MAPS_API_TOKEN": "secret"}), \
                mock.patch("sys.stdout", io.StringIO()), mock.patch("sys.stderr", io.StringIO()):
            ttl_text, audit = build_ttl(
                args=namespace, tasks=[task], stages=[{"slug": "test", "label": "Test", "tasks": [task]}],
                pod_metrics={"nf-test": PodMetrics(pod_name="nf-test", cpu_seconds=1.0, energy_joules=3600.0,
                                                   node_name=NODE)},
                run_start=START, run_end=END, run_status="Succeeded",
                log_metadata={"session_id": "s", "run_name": "r", "nextflow_version": "25.04.8",
                              "failure_reason": None},
                code_version="abc", git_commit=None, git_dirty=None, energy_metric="kepler_container_joules_total",
                carbon_info=CarbonIntensityInfo(kg_per_kwh=0.3, source="test"), node_infos=[], images=[],
                responsible_researchers=[], responsible_researcher_uris=[], subproject_uris=[], language_uris=[],
                input_datasets=[], node_use=EXCLUSIVE)
        self.assertTrue(audit["node_power"]["applied"])
        self.assertIn('rm:energyMeasurementCoverage "100% of the node (whole node, measured)"', ttl_text)
        self.assertIn("rm:nodeIdlePowerW", ttl_text)
        self.assertIn("rm:gridCarbonIntensityHours", ttl_text)
        self.assertIn("rm:energyKWh " + ttl_literal(audit["node_power"]["node_energy_kwh"]), ttl_text)


if __name__ == "__main__":
    unittest.main()
