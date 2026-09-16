import unittest

from tools.analyze_results import percentile, summarize_group


class AnalyzeResultsTests(unittest.TestCase):
    def test_percentile_interpolates(self):
        self.assertEqual(percentile([1.0], 0.99), 1.0)
        self.assertAlmostEqual(percentile([0.0, 100.0], 0.5), 50.0)

    def test_clean_group_passes(self):
        rows = [
            {
                "controller": "ac702",
                "mode": "CSP",
                "requested_cycle_us": "1000",
                "actual_cycle_us": "1000",
                "task_delta_us": "1001",
                "jitter_us": "1",
                "dc_deviation_ns": "500",
                "pdo_latency_us": "800",
                "wkc_ok": "true",
                "lost_frames": "0",
                "following_error": "0.01",
                "cpu_load_pct": "40",
            },
            {
                "controller": "ac702",
                "mode": "CSP",
                "requested_cycle_us": "1000",
                "actual_cycle_us": "1000",
                "task_delta_us": "999",
                "jitter_us": "-1",
                "dc_deviation_ns": "-600",
                "pdo_latency_us": "820",
                "wkc_ok": "true",
                "lost_frames": "0",
                "following_error": "-0.02",
                "cpu_load_pct": "45",
            },
        ]
        summary = summarize_group(rows, following_error_limit=0.1)
        self.assertEqual(summary["status"], "PASS")
        self.assertEqual(summary["bad_wkc_samples"], 0)
        self.assertEqual(summary["missing_metrics"], [])

    def test_missing_required_metrics_are_incomplete(self):
        rows = [{
            "controller": "zmc432-16-v2",
            "mode": "CSP",
            "requested_cycle_us": "1000",
            "actual_cycle_us": "1000",
            "task_delta_us": "1002",
            "jitter_us": "2",
            "following_error": "0.01",
        }]
        summary = summarize_group(rows)
        self.assertEqual(summary["status"], "INCOMPLETE")
        self.assertIn("dc_deviation", summary["missing_metrics"])
        self.assertIn("wkc", summary["missing_metrics"])
        self.assertIn("pdo_latency", summary["missing_metrics"])
        self.assertIn("cpu_load", summary["missing_metrics"])

    def test_bad_wkc_and_loss_fail(self):
        rows = [{
            "controller": "zmc432-16-v2",
            "mode": "CSP",
            "requested_cycle_us": "500",
            "task_delta_us": "500",
            "jitter_us": "2",
            "wkc_ok": "false",
            "lost_frames": "1",
        }]
        summary = summarize_group(rows)
        self.assertEqual(summary["status"], "FAIL")
        self.assertTrue(any("bad WKC" in reason for reason in summary["reasons"]))
        self.assertTrue(any("lost_frames" in reason for reason in summary["reasons"]))

    def test_explicit_unsupported_is_not_failure(self):
        rows = [{
            "controller": "ac702",
            "mode": "CST",
            "requested_cycle_us": "125",
            "status": "UNSUPPORTED",
        }]
        summary = summarize_group(rows)
        self.assertEqual(summary["status"], "UNSUPPORTED")
        self.assertIn("task_jitter", summary["missing_metrics"])

    def test_jitter_can_be_derived_from_task_delta(self):
        rows = [{
            "controller": "zmc432-16-v2",
            "mode": "CSP",
            "requested_cycle_us": "1000",
            "task_delta_us": "1010",
        }]
        summary = summarize_group(rows)
        self.assertEqual(summary["jitter_abs_us"]["max"], 10.0)
        self.assertEqual(summary["status"], "INCOMPLETE")


if __name__ == "__main__":
    unittest.main()
