"""Node CPU utilisation, CPU efficiency and fan speed of an exclusive single-node run, and the Nextflow driver
pod found in the debug log (collect_nextflow_run_metadata.py). Simulated Prometheus and Electricity Maps."""
import io
import os
import re
import unittest
from unittest import mock

from collector import collect_nextflow_run_metadata as collector
from collector.collect_nextflow_run_metadata import driver_pod_from_log, node_power_apply, ttl_literal

import test_node_power_collector as base

DRIVER = "rangeland-series-c39-qt9jw"
TASK_CPU = 1500.0     # s, from the trace (rm:cpuTimeSeconds)
DRIVER_CPU = 64.5     # s
NODE_BUSY = 2580.0    # s of CPU time of the whole node during the 215 s run (12.0 CPUs)
FAN_RPM = (6000.0, 6600.0)


class Services(base.FakeServices):
    def __init__(self, cpus=32, capacity=None, fans=True, **kw):
        super().__init__(**kw)
        self.cpus, self.capacity, self.fans = cpus, capacity, fans

    def __call__(self, url, params=None, headers=None):
        query = (params or {}).get("query", "")

        def instant(value):
            self.calls.append((url, dict(params)))
            result = [] if value is None else [{"metric": {}, "value": [params["time"], str(value)]}]
            return {"status": "success", "data": {"result": result}}

        if "machine_cpu_cores" in query:
            return instant(self.cpus)
        if "kube_node_status_capacity" in query:
            return instant(self.capacity)
        if "node_hwmon_fan_rpm" in query:
            assert f'nodename="{base.NODE}"' in query, query
            if not self.fans:
                self.calls.append((url, dict(params)))
                return {"status": "success", "data": {"result": []}}
            if url.endswith("/query_range"):
                self.calls.append((url, dict(params)))
                value = FAN_RPM[1] if query.startswith("max(") else sum(FAN_RPM) / 2
                start, end, step = float(params["start"]), float(params["end"]), float(params["step"][:-1])
                n = int((end - start) // step) + 1
                values = [[start + i * step, str(value)] for i in range(n)]
                return {"status": "success", "data": {"result": [{"metric": {}, "values": values}]}}
            return instant(len(FAN_RPM))
        if "increase(container_cpu_usage_seconds_total" in query:
            if f'pod="{DRIVER}"' in query:
                assert 'namespace="yagmur"' in query, query
                return instant(DRIVER_CPU)
            assert 'id="/"' in query and f'node="{base.NODE}"' in query, query
            assert "[215s]" in query, query
            return instant(NODE_BUSY)
        return super().__call__(url, params, headers)


def args(**extra):
    values = dict(namespace="yagmur", detected_driver_pod=DRIVER)
    values.update(extra)
    return base.args(**values)


def predicates():
    return base.predicates() + [("rm:cpuTimeSeconds", ttl_literal(TASK_CPU))]


class NodeConditionsTests(unittest.TestCase):
    def apply(self, preds, run_args=None, services=None):
        services = services or Services()
        with mock.patch.object(collector, "http_get_json", side_effect=services), \
                mock.patch.dict(os.environ, {"ELECTRICITY_MAPS_API_TOKEN": "secret"}, clear=False), \
                mock.patch("sys.stdout", io.StringIO()), mock.patch("sys.stderr", io.StringIO()) as err:
            summary = node_power_apply(run_args or args(), preds, [base.NODE], base.EXCLUSIVE, base.START, base.END,
                                       now=base.E + 3600)
        return summary, dict(preds), err.getvalue()

    def test_values_and_method(self):
        preds = predicates()
        summary, values, err = self.apply(preds)
        self.assertTrue(summary["applied"], err)
        self.assertNotIn("WARNING: node CPU", err)
        self.assertEqual(values["rm:nodeCpuUtilizationAvgPercent"], ttl_literal(37.5))   # 12 of 32 CPUs
        efficiency = round(100 * (TASK_CPU + DRIVER_CPU) / (32 * 215), 1)
        self.assertEqual(values["rm:cpuEfficiencyPercent"], ttl_literal(efficiency))
        self.assertEqual(values["rm:fanSpeedAvgRPM"], ttl_literal(6300.0))
        method = values["rm:nodeConditionsMethod"]
        self.assertTrue(method.startswith('"Idle power: '), method)
        self.assertIn("Node CPU utilisation: CPU time of all processes on the node", method)
        self.assertIn("(12.0 of 32 CPUs busy on average)", method)
        self.assertIn(f"tasks 1500 s from the Nextflow trace + the Nextflow driver pod {DRIVER} 64 s from cAdvisor",
                      method)
        self.assertIn("Fan speed: fan sensors of the node (node_exporter, node_hwmon_fan_rpm), 2 fans", method)
        self.assertIn("highest 6600 rpm", method)
        for prop in ("rm:nodeConditionsMethod", "rm:cpuEfficiencyPercent", "rm:nodeCpuUtilizationAvgPercent",
                     "rm:fanSpeedAvgRPM"):
            self.assertEqual(len([p for p, _ in preds if p == prop]), 1, prop)
        self.assertAlmostEqual(summary["node_conditions"]["driver_cpu_seconds"], DRIVER_CPU)

    def test_node_without_fan_sensors(self):
        summary, values, err = self.apply(predicates(), services=Services(fans=False))
        self.assertNotIn("rm:fanSpeedAvgRPM", values)
        self.assertNotIn("Fan speed", values["rm:nodeConditionsMethod"])
        self.assertIn("rm:cpuEfficiencyPercent", values)
        self.assertIn("no fan sensors", summary["node_conditions"]["fans"])

    def test_cpu_count_from_kube_state_metrics(self):
        _, values, _ = self.apply(predicates(), services=Services(cpus=None, capacity=32))
        self.assertEqual(values["rm:nodeCpuUtilizationAvgPercent"], ttl_literal(37.5))
        self.assertIn("kube_node_status_capacity", values["rm:nodeConditionsMethod"])

    def test_driver_not_found(self):
        _, values, _ = self.apply(predicates(), run_args=args(detected_driver_pod=None))
        self.assertEqual(values["rm:cpuEfficiencyPercent"], ttl_literal(round(100 * TASK_CPU / (32 * 215), 1)))
        self.assertIn("without the Nextflow driver, whose pod was not found", values["rm:nodeConditionsMethod"])

    def test_unknown_cpu_count_keeps_the_node_power(self):
        summary, values, err = self.apply(predicates(), services=Services(cpus=None, capacity=None))
        self.assertTrue(summary["applied"])
        self.assertIn("rm:nodeIdlePowerW", values)
        self.assertNotIn("rm:cpuEfficiencyPercent", values)
        self.assertIn("WARNING: node CPU utilisation, CPU efficiency and fan speed not added", err)
        self.assertIn("error", summary["node_conditions"])

    def test_driver_pod_from_debug_log(self):
        log = ("Oct-20 17:20:05.123 [main] DEBUG nextflow.cli.Launcher - $> nextflow run nf-core/rangeland\n"
               "  Version: 25.04.8 build 5956\n"
               f"  Process: 7@{DRIVER} [10.233.77.91]\n"
               "  CPUs: 2 - Mem: 3 GB (2.9 GB) - Swap: 0 (0)\n")
        self.assertEqual(driver_pod_from_log(log), DRIVER)
        self.assertIsNone(driver_pod_from_log(""))
        self.assertIsNone(driver_pod_from_log(None))
        self.assertIsNone(driver_pod_from_log("Process: 7@Not_A_Pod [1.2.3.4]\n"))


if __name__ == "__main__":
    unittest.main()
