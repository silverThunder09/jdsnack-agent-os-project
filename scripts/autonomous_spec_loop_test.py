#!/usr/bin/env python3
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "scripts/autonomous_spec_loop.py"


class AutonomousSpecLoopTest(unittest.TestCase):
    def setUp(self):
        self.temp = Path(tempfile.mkdtemp(prefix="jdsnack-autonomous-loop-"))
        (self.temp / ".agent-os/standards").mkdir(parents=True)
        (self.temp / ".agent-os/product").mkdir(parents=True)
        (self.temp / ".agent-os/specs/current").mkdir(parents=True)
        (self.temp / ".agent-os/standards/index.yml").write_text(
            "active_specs:\n  - .agent-os/specs/current\n", encoding="utf-8"
        )
        (self.temp / ".agent-os/specs/current/plan.md").write_text(
            "# Plan\n- 구현 상태: `completed`\n\n### T1. First\n- 상태: `completed`\n", encoding="utf-8"
        )
        queue = {
            "version": 1,
            "candidates": [
                {
                    "id": "next-feature",
                    "slug": "next-feature",
                    "priority": 1,
                    "status": "candidate",
                    "auto_promote": True,
                    "start_condition": {"type": "feature_completed", "feature": "current"},
                },
                {
                    "id": "later-feature",
                    "slug": "later-feature",
                    "priority": 2,
                    "status": "candidate",
                    "auto_promote": True,
                    "start_condition": {"type": "issue_label", "label": "product-signal:later"},
                },
            ],
        }
        (self.temp / ".agent-os/product/spec-queue.json").write_text(
            json.dumps(queue), encoding="utf-8"
        )

    def tearDown(self):
        shutil.rmtree(self.temp)

    def run_engine(self, *args):
        return subprocess.run(
            ["python3", str(ENGINE), *args, "--repo", str(self.temp)],
            check=False,
            text=True,
            capture_output=True,
        )

    def test_completed_feature_selects_next_candidate(self):
        result = self.run_engine("decide", "--event", "push", "--event-key", "merge:123")
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "promote_spec")
        self.assertEqual(payload["candidate"]["id"], "next-feature")

    def test_no_signal_stops_instead_of_guessing(self):
        result = self.run_engine("decide", "--event", "push", "--event-key", "merge:123")
        payload = json.loads(result.stdout)
        self.assertNotEqual(payload["candidate"]["id"], "later-feature")

    def test_duplicate_event_is_idempotent(self):
        first = self.run_engine("record", "--event-key", "merge:123")
        self.assertEqual(first.returncode, 0, first.stderr)
        second = self.run_engine("decide", "--event", "push", "--event-key", "merge:123")
        payload = json.loads(second.stdout)
        self.assertEqual(payload["status"], "no_action")
        self.assertEqual(payload["reason"], "duplicate_event")

    def test_issue_signal_unlocks_candidate(self):
        result = self.run_engine(
            "decide", "--event", "issues", "--event-key", "issue:1", "--signal", "product-signal:later"
        )
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "promote_spec")
        self.assertEqual(payload["candidate"]["id"], "next-feature")

    def test_activated_spec_dispatches_first_ticket(self):
        (self.temp / ".agent-os/standards/index.yml").write_text(
            "active_specs:\n  - .agent-os/specs/next-feature\n", encoding="utf-8"
        )
        (self.temp / ".agent-os/specs/next-feature").mkdir()
        (self.temp / ".agent-os/specs/next-feature/plan.md").write_text(
            "# Plan\n- 구현 상태: `in_progress`\n\n"
            "### T1. First vertical slice\n- 상태: `ready`\n\n"
            "### T2. Follow-up\n- 상태: `pending`\n",
            encoding="utf-8",
        )
        queue = json.loads((self.temp / ".agent-os/product/spec-queue.json").read_text())
        queue["candidates"][0]["status"] = "active"
        (self.temp / ".agent-os/product/spec-queue.json").write_text(
            json.dumps(queue), encoding="utf-8"
        )

        result = self.run_engine("decide", "--event", "push", "--event-key", "merge:next")
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "dispatch_codex")
        self.assertEqual(payload["spec_slug"], "next-feature")
        self.assertEqual(payload["ticket_id"], "T1")

    def test_in_flight_claim_is_cleared_after_record(self):
        claimed = self.run_engine(
            "claim", "--event-key", "merge:claim", "--status", "dispatch_codex", "--branch", "codex/current-T1"
        )
        self.assertEqual(claimed.returncode, 0, claimed.stderr)
        state_path = self.temp / ".agent-os/runtime/autonomous-loop-state.json"
        self.assertEqual(json.loads(state_path.read_text())["in_flight"]["branch"], "codex/current-T1")

        recorded = self.run_engine("record", "--event-key", "merge:claim")
        self.assertEqual(recorded.returncode, 0, recorded.stderr)
        self.assertNotIn("in_flight", json.loads(state_path.read_text()))


if __name__ == "__main__":
    unittest.main()
