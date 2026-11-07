"""Time-matched carbon intensity of a run: 15-minute Electricity Maps values first, hourly otherwise."""
import argparse
from datetime import datetime, timezone
import os
from pathlib import Path
import sys
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "collector"))
import collect_nextflow_run_metadata as collector  # noqa: E402

START = datetime(2026, 10, 20, 13, 7, tzinfo=timezone.utc)
END = datetime(2026, 10, 20, 13, 38, tzinfo=timezone.utc)


def args():
    return argparse.Namespace(
        carbon_intensity_source="electricity-maps", electricity_maps_api_token_env="ELECTRICITY_MAPS_API_TOKEN",
        electricity_maps_zone="DE", electricity_maps_api_url="https://api.electricitymaps.com/v4/carbon-intensity/past-range",
        electricity_maps_disable_estimations=False)


class FifteenMinuteCarbonTests(unittest.TestCase):
    def resolve(self, answer):
        calls = []

        def fake(url, params=None, headers=None):
            calls.append(dict(params))
            return answer(params)
        with mock.patch.object(collector, "http_get_json", side_effect=fake), \
                mock.patch.dict(os.environ, {"ELECTRICITY_MAPS_API_TOKEN": "test-only"}):
            return collector.resolve_carbon_intensity(args(), START, END), calls

    def test_quarter_hours_of_the_run_are_used(self):
        def answer(params):
            self.assertEqual(params["temporalGranularity"], "15_minutes")
            return {"zone": "DE", "temporalGranularity": "15_minutes", "data": [
                {"datetime": f"2026-10-20T13:{m:02d}:00.000Z", "carbonIntensity": v, "isEstimated": False}
                for m, v in ((0, 300), (15, 310), (30, 320))]}
        info, calls = self.resolve(answer)
        self.assertEqual((calls[0]["start"], calls[0]["end"]), ("2026-10-20T13:00:00Z", "2026-10-20T13:45:00Z"))
        self.assertEqual(info.temporal_granularity, "15 minutes")
        self.assertAlmostEqual(info.kg_per_kwh, 0.31)
        self.assertEqual(info.point_count, 3)
        self.assertIn("15-minute history", info.source)

    def test_hourly_values_when_the_account_has_no_quarter_hours(self):
        def answer(params):
            if params["temporalGranularity"] == "15_minutes":
                raise RuntimeError("HTTP 403 returned by Electricity Maps")
            return {"zone": "DE", "temporalGranularity": "hourly",
                    "data": [{"datetime": "2026-10-20T13:00:00.000Z", "carbonIntensity": 280}]}
        info, calls = self.resolve(answer)
        self.assertEqual([c["temporalGranularity"] for c in calls], ["15_minutes", "hourly"])
        self.assertEqual(info.temporal_granularity, "hourly")
        self.assertAlmostEqual(info.kg_per_kwh, 0.28)

    def test_no_data_at_all_stops_with_both_reasons(self):
        def answer(params):
            raise RuntimeError("HTTP 403 returned by Electricity Maps")
        with self.assertRaises(RuntimeError) as ctx:
            self.resolve(answer)
        self.assertIn("15_minutes", str(ctx.exception))
        self.assertIn("hourly", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
