"""A publication links to the workflow (rm:usesWorkflow / rm:usedInPublication), never to a run.

rm:hasWorkflowRun is the inverse of rm:workflow. A publication that held a run through it made
VIVO's reasoner infer that the publication was the run's workflow.
"""
import argparse
import unittest

from collector.collect_nextflow_run_metadata import (
    CarbonIntensityInfo, PodMetrics, TaskRecord, build_ttl)
from tests.test_kubernetes_node_use import END, START

PUBLICATION = "http://example.org/vivo/individual/a1-publication-test"
WORKFLOW = "https://example.org/workflow/test"


def ttl(publication_uri):
    task = TaskRecord(task_id="1", hash_value="aa/1", pod_name="nf-test", name="test", status="COMPLETED",
                      exit_code=0, submit=START, duration_seconds=2.0, realtime_seconds=1.0, end=END)
    args = argparse.Namespace(
        application_domain_uri="", backend_uri="", base_uri="http://example.org/vivo-import/run-metadata/",
        cluster_label="Fonda Cluster", cluster_uri="https://example.org/cluster", code_uri="",
        engine_uri="", include_cached_origin_metrics=False, namespace="test",
        ontology_uri="http://example.org/ontology/run-metadata#", prom_url="http://127.0.0.1:19090",
        publication_uri=publication_uri, run_identity_scope="fonda", run_operator_uri="", trace_archive="",
        workflow_trace_repository="", run_trace_archive="", trace_data_format="TSV",
        trace_types="Nextflow trace", workflow_name="Publication link test", workflow_repo_url="",
        workflow_uri=WORKFLOW)
    text, _ = build_ttl(
        args=args, tasks=[task], stages=[{"slug": "test", "label": "Test", "tasks": [task]}],
        pod_metrics={"nf-test": PodMetrics(pod_name="nf-test", cpu_seconds=1.0, energy_joules=3600.0)},
        run_start=START, run_end=END, run_status="Succeeded",
        log_metadata={"session_id": "s", "run_name": "r", "nextflow_version": "25.04.8", "failure_reason": None},
        code_version="abc", git_commit=None, git_dirty=None, energy_metric="kepler_container_joules_total",
        carbon_info=CarbonIntensityInfo(kg_per_kwh=0.3, source="test"), node_infos=[], images=[],
        responsible_researchers=[], responsible_researcher_uris=[], subproject_uris=[], language_uris=[],
        input_datasets=[])
    return text


class PublicationLinkTests(unittest.TestCase):
    def test_publication_links_to_the_workflow_not_the_run(self) -> None:
        text = ttl(PUBLICATION)
        publication_block = text.split(f"\n<{PUBLICATION}>\n", 1)[1].split("\n\n", 1)[0]
        self.assertIn(f"rm:usesWorkflow <{WORKFLOW}>", publication_block)
        self.assertNotIn("rm:hasWorkflowRun", publication_block)
        self.assertIn(f"rm:usedInPublication <{PUBLICATION}>", text)

    def test_no_publication_no_link(self) -> None:
        text = ttl("")
        self.assertNotIn("rm:usesWorkflow <", text)
        self.assertNotIn("rm:usedInPublication", text)


if __name__ == "__main__":
    unittest.main()
