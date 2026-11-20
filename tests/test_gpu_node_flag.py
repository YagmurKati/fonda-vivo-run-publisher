"""GPU flag of a FONDA run from the nodes' pci-10de label (gpu_node_predicates) and the meter-check
sentence of whole-node runs (node_power_apply)."""
import io
import unittest
from unittest import mock

from collector import collect_nextflow_run_metadata as collector
from collector.collect_nextflow_run_metadata import gpu_node_predicates, node_has_nvidia_gpu, ttl_literal

API_GPU = {"name": "hu-worker-c39", "labels": {"feature.node.kubernetes.io/pci-10de.present": "true",
                                               "feature.node.kubernetes.io/cpu-model.vendor_id": "Intel"}}
API_NO_GPU = {"name": "hu-worker-c41", "labels": {"feature.node.kubernetes.io/cpu-model.vendor_id": "Intel",
                                                  "kubernetes.io/hostname": "hu-worker-c41"}}
PROM_GPU = {"name": "hu-worker-c34", "labels": {"label_feature_node_kubernetes_io_pci_10de_present": "true"}}
NO_LABELS = {"name": "hu-worker-c40", "labels": {}}
NO_NFD = {"name": "hu-worker-c40", "labels": {"kubernetes.io/hostname": "hu-worker-c40"}}


def run(nodes, infos, whole=False):
    with mock.patch("sys.stderr", io.StringIO()) as err:
        preds, summary = gpu_node_predicates(nodes, infos, whole, checked="2026-11-20")
    return dict(preds), summary, err.getvalue()


class NodeLabelTests(unittest.TestCase):
    def test_labels(self):
        self.assertTrue(node_has_nvidia_gpu(API_GPU))
        self.assertTrue(node_has_nvidia_gpu(PROM_GPU))
        self.assertFalse(node_has_nvidia_gpu(API_NO_GPU))
        self.assertIsNone(node_has_nvidia_gpu(NO_LABELS))
        self.assertIsNone(node_has_nvidia_gpu(NO_NFD))


class GpuPredicateTests(unittest.TestCase):
    def test_whole_node_run_on_a_gpu_node(self):
        values, summary, _ = run(["hu-worker-c39"], [API_GPU], whole=True)
        self.assertEqual(values["rm:gpuCapableNodeUsed"], ttl_literal(True))
        self.assertIn("The node has an NVIDIA GPU that the run did not use; its idle power is part of the node "
                      "energy", values["rm:gpuUsageStatus"])
        self.assertIn("checked 2026-11-20", values["rm:gpuUsageStatus"])
        self.assertTrue(summary["gpu_capable_node_used"])

    def test_several_nodes_one_with_gpu(self):
        values, _, _ = run(["hu-worker-c41", "hu-worker-c34", "hu-worker-c41"], [API_NO_GPU, PROM_GPU])
        self.assertEqual(values["rm:gpuCapableNodeUsed"], ttl_literal(True))
        self.assertIn("At least one node used by the run has an NVIDIA GPU", values["rm:gpuUsageStatus"])
        self.assertNotIn("idle power", values["rm:gpuUsageStatus"])

    def test_pod_energy_run_on_one_gpu_node(self):
        values, _, _ = run(["hu-worker-c39"], [API_GPU], whole=False)
        self.assertIn("At least one node used by the run has", values["rm:gpuUsageStatus"])

    def test_no_gpu_node(self):
        values, _, _ = run(["hu-worker-c41"], [API_NO_GPU], whole=True)
        self.assertEqual(values["rm:gpuCapableNodeUsed"], ttl_literal(False))
        self.assertIn("No node used by the run has an NVIDIA GPU", values["rm:gpuUsageStatus"])

    def test_unknown_node_leaves_the_flag_out(self):
        values, summary, err = run(["hu-worker-c41", "hu-worker-c40"], [API_NO_GPU, NO_LABELS])
        self.assertNotIn("rm:gpuCapableNodeUsed", values)
        self.assertIn("unknown", values["rm:gpuUsageStatus"])
        self.assertIn("hu-worker-c40", values["rm:gpuUsageStatus"])
        self.assertIsNone(summary["gpu_capable_node_used"])
        self.assertIn("WARNING", err)

    def test_a_gpu_node_decides_even_if_another_is_unknown(self):
        values, _, _ = run(["hu-worker-c39", "hu-worker-c40"], [API_GPU, NO_LABELS])
        self.assertEqual(values["rm:gpuCapableNodeUsed"], ttl_literal(True))

    def test_node_missing_from_the_node_infos(self):
        values, _, _ = run(["hu-worker-c39"], [])
        self.assertNotIn("rm:gpuCapableNodeUsed", values)


class PrometheusLabelTests(unittest.TestCase):
    def test_fallback_reads_kube_node_labels(self):
        def fake(prom_url, query):
            if query.startswith("kube_node_labels"):
                return [{"metric": {"node": "hu-worker-c34",
                                    "label_feature_node_kubernetes_io_pci_10de_present": "true"}}]
            return []
        with mock.patch.object(collector, "prom_query", side_effect=fake):
            info = collector.collect_prometheus_node_info("http://prometheus:9090", "hu-worker-c34")
        self.assertTrue(node_has_nvidia_gpu(info))
        self.assertNotIn("node", info["labels"])


class MeterCheckTests(unittest.TestCase):
    def test_whole_node_energy_method_has_the_meter_check(self):
        from tests.test_node_power_collector import NodePowerTests, predicates
        case = NodePowerTests()
        summary, values, err, _ = case.apply(predicates())
        self.assertTrue(summary["applied"], err)
        self.assertTrue(values["rm:energyCalculationMethod"].rstrip('"').endswith(
            "agreed with the node's IPMI reading within 1% over one rangeland run and 25 minutes idle (2026-11-14)."))


if __name__ == "__main__":
    unittest.main()
