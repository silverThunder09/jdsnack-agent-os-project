#!/usr/bin/env python3
"""Deterministic decision engine for the JDSnack autonomous implementation loop.

The engine never invents product scope. It only validates the active spec,
selects an eligible queue candidate, and emits a dispatch decision for the
runner that owns Claude/Codex credentials.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


class LoopError(RuntimeError):
    pass


@dataclass(frozen=True)
class ActiveSpec:
    path: str
    slug: str
    complete: bool
    next_ticket: str | None


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise LoopError(f"missing JSON: {path}") from exc
    except json.JSONDecodeError as exc:
        raise LoopError(f"invalid JSON: {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise LoopError(f"JSON root must be an object: {path}")
    return value


def parse_active_specs(index_path: Path) -> list[str]:
    if not index_path.exists():
        raise LoopError(f"missing standards index: {index_path}")
    active = False
    specs: list[str] = []
    for raw in index_path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        if line == "active_specs:":
            active = True
            continue
        if active and line and not line[0].isspace():
            break
        if active:
            match = re.match(r"^\s+-\s+(.+?)\s*$", line)
            if match:
                specs.append(match.group(1))
    return specs


def parse_plan(spec_path: Path) -> ActiveSpec:
    plan_path = spec_path / "plan.md"
    if not plan_path.exists():
        raise LoopError(f"active spec has no plan.md: {spec_path}")
    text = plan_path.read_text(encoding="utf-8")
    slug = spec_path.name
    feature_complete = bool(re.search(r"구현 상태:\s*`completed`", text))
    ticket_statuses = re.findall(r"- 상태:\s*`([^`]+)`", text)
    if not ticket_statuses:
        raise LoopError(f"plan has no ticket statuses: {plan_path}")
    complete = feature_complete and all(status == "completed" for status in ticket_statuses)
    next_ticket: str | None = None
    sections = re.split(r"(?=^###\s+T\d+\.)", text, flags=re.MULTILINE)
    for section in sections:
        heading = re.search(r"^###\s+(T\d+)\.", section, flags=re.MULTILINE)
        status = re.search(r"- 상태:\s*`([^`]+)`", section)
        if heading and status and status.group(1) != "completed":
            next_ticket = heading.group(1)
            break
    return ActiveSpec(str(spec_path), slug, complete, next_ticket)


def load_state(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"version": 1, "processed_events": [], "signals": []}
    return load_json(path)


def write_state(path: Path, state: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temp.replace(path)


def candidate_is_eligible(candidate: dict[str, Any], completed: set[str], signals: set[str]) -> bool:
    if candidate.get("status") != "candidate" or not candidate.get("auto_promote", False):
        return False
    prerequisites = set(candidate.get("requires", []))
    if not prerequisites.issubset(completed):
        return False
    condition = candidate.get("start_condition", {})
    condition_type = condition.get("type")
    if condition_type == "bootstrap":
        return True
    if condition_type == "always":
        return True
    if condition_type == "issue":
        return True
    if condition_type == "feature_completed":
        return condition.get("feature") in completed
    if condition_type == "issue_label":
        return condition.get("label") in signals
    return False


def choose_candidate(
    queue: dict[str, Any],
    completed: set[str],
    signals: set[str],
    extra_candidates: list[dict[str, Any]] | None = None,
) -> dict[str, Any] | None:
    candidates = queue.get("candidates")
    if not isinstance(candidates, list):
        raise LoopError("spec queue must contain candidates[]")
    all_candidates = candidates + (extra_candidates or [])
    eligible = [candidate for candidate in all_candidates if candidate_is_eligible(candidate, completed, signals)]
    eligible.sort(key=lambda item: (int(item.get("priority", 999999)), str(item.get("id", ""))))
    return eligible[0] if eligible else None


def decision(repo: Path, event: str, event_key: str, signals: set[str]) -> dict[str, Any]:
    index_path = repo / ".agent-os/standards/index.yml"
    queue_path = repo / ".agent-os/product/spec-queue.json"
    state_path = repo / ".agent-os/runtime/autonomous-loop-state.json"
    queue = load_json(queue_path)
    state = load_state(state_path)

    if event_key and event_key in set(state.get("processed_events", [])):
        return {"status": "no_action", "reason": "duplicate_event", "event_key": event_key}

    active_paths = parse_active_specs(index_path)
    if len(active_paths) > 1:
        raise LoopError(f"more than one active spec: {active_paths}")

    completed = {
        str(candidate.get("id"))
        for candidate in queue.get("candidates", [])
        if candidate.get("status") == "completed"
    }
    completed.update(state.get("completed_features", []))
    signals = set(signals) | set(state.get("signals", []))

    if active_paths:
        active = parse_plan(repo / active_paths[0])
        if not active.complete:
            if active.next_ticket:
                return {
                    "status": "dispatch_codex",
                    "reason": "active_spec_has_ready_ticket",
                    "event": event,
                    "event_key": event_key,
                    "spec_path": active.path,
                    "spec_slug": active.slug,
                    "ticket_id": active.next_ticket,
                }
            return {
                "status": "needs_human",
                "reason": "active_spec_has_no_ready_ticket",
                "event": event,
                "event_key": event_key,
                "spec_path": active.path,
            }

        completed.add(active.slug)
        for candidate_item in queue.get("candidates", []):
            if candidate_item.get("slug") == active.slug:
                completed.add(str(candidate_item.get("id")))

    issue_candidates = state.get("issue_candidates", [])
    if not isinstance(issue_candidates, list):
        raise LoopError("runtime issue_candidates must be a list")
    candidate = choose_candidate(queue, completed, signals, issue_candidates)
    if candidate:
        return {
            "status": "promote_spec",
            "reason": "completed_feature_has_eligible_candidate" if active_paths else "no_active_spec_has_eligible_candidate",
            "event": event,
            "event_key": event_key,
            "candidate": candidate,
            "completed_features": sorted(completed),
        }

    remaining = [c for c in queue.get("candidates", []) if c.get("status") == "candidate"]
    remaining.extend(c for c in issue_candidates if c.get("status") == "candidate")
    if remaining:
        return {
            "status": "needs_human",
            "reason": "no_candidate_start_condition_satisfied",
            "event": event,
            "event_key": event_key,
            "remaining_candidates": [c.get("id") for c in remaining],
        }
    return {"status": "idle", "reason": "spec_queue_exhausted", "event": event, "event_key": event_key}


def record_event(
    repo: Path,
    event_key: str,
    signal: str | None = None,
    completed: str | None = None,
    promoted_candidate: str | None = None,
) -> None:
    state_path = repo / ".agent-os/runtime/autonomous-loop-state.json"
    state = load_state(state_path)
    events = list(state.get("processed_events", []))
    if event_key and event_key not in events:
        events.append(event_key)
    state["processed_events"] = events[-100:]
    signals = set(state.get("signals", []))
    if signal:
        signals.add(signal)
    state["signals"] = sorted(signals)
    completed_features = set(state.get("completed_features", []))
    if completed:
        completed_features.add(completed)
    state["completed_features"] = sorted(completed_features)
    if promoted_candidate:
        state["issue_candidates"] = [
            candidate
            for candidate in state.get("issue_candidates", [])
            if str(candidate.get("id")) != promoted_candidate
        ]
    state.pop("in_flight", None)
    write_state(state_path, state)


def ingest_issue(repo: Path, issue_number: str, title: str) -> None:
    state_path = repo / ".agent-os/runtime/autonomous-loop-state.json"
    state = load_state(state_path)
    candidates = list(state.get("issue_candidates", []))
    issue_id = f"issue-{issue_number}"
    if not any(str(candidate.get("id")) == issue_id for candidate in candidates):
        candidates.append(
            {
                "id": issue_id,
                "slug": issue_id,
                "title": title,
                "priority": 0,
                "status": "candidate",
                "auto_promote": True,
                "source_issue": issue_number,
                "start_condition": {"type": "issue"},
            }
        )
    state["issue_candidates"] = candidates
    write_state(state_path, state)


def claim_event(repo: Path, event_key: str, status: str, branch: str) -> None:
    state_path = repo / ".agent-os/runtime/autonomous-loop-state.json"
    state = load_state(state_path)
    state["in_flight"] = {"event_key": event_key, "status": status, "branch": branch}
    write_state(state_path, state)


def validate_queue(queue: dict[str, Any]) -> int:
    candidates = queue.get("candidates")
    if not isinstance(candidates, list):
        raise LoopError("spec queue must contain candidates[]")
    ids = [candidate.get("id") for candidate in candidates]
    if len(ids) != len(set(ids)):
        raise LoopError("spec queue contains duplicate candidate ids")
    allowed_statuses = {"candidate", "active", "completed", "blocked"}
    required = {"id", "slug", "title", "priority", "status", "auto_promote", "start_condition"}
    active = []
    for candidate in candidates:
        missing = sorted(required - candidate.keys())
        if missing:
            raise LoopError(f"candidate {candidate.get('id')} missing fields: {', '.join(missing)}")
        if candidate["status"] not in allowed_statuses:
            raise LoopError(f"candidate {candidate['id']} has invalid status: {candidate['status']}")
        if not isinstance(candidate["priority"], int):
            raise LoopError(f"candidate {candidate['id']} priority must be an integer")
        if not isinstance(candidate["start_condition"], dict) or not candidate["start_condition"].get("type"):
            raise LoopError(f"candidate {candidate['id']} has invalid start_condition")
        if candidate["status"] == "active":
            active.append(candidate)
    if len(active) > 1:
        raise LoopError("spec queue contains more than one active candidate")
    return len(candidates)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["decide", "record", "validate", "ingest-issue", "claim"])
    parser.add_argument("--repo", default=".")
    parser.add_argument("--event", default="manual")
    parser.add_argument("--event-key", default="")
    parser.add_argument("--signal", action="append", default=[])
    parser.add_argument("--completed")
    parser.add_argument("--promoted-candidate")
    parser.add_argument("--issue-number")
    parser.add_argument("--issue-title")
    parser.add_argument("--status")
    parser.add_argument("--branch")
    args = parser.parse_args()
    repo = Path(args.repo).resolve()
    try:
        if args.command == "validate":
            queue = load_json(repo / ".agent-os/product/spec-queue.json")
            candidate_count = validate_queue(queue)
            print(json.dumps({"status": "valid", "candidate_count": candidate_count}, ensure_ascii=False))
            return 0
        if args.command == "ingest-issue":
            if not args.issue_number or not args.issue_title:
                raise LoopError("ingest-issue requires --issue-number and --issue-title")
            ingest_issue(repo, args.issue_number, args.issue_title)
            print(json.dumps({"status": "issue_queued", "issue_number": args.issue_number}, ensure_ascii=False))
            return 0
        if args.command == "claim":
            if not args.event_key or not args.status or not args.branch:
                raise LoopError("claim requires --event-key, --status, and --branch")
            claim_event(repo, args.event_key, args.status, args.branch)
            print(json.dumps({"status": "claimed", "event_key": args.event_key}, ensure_ascii=False))
            return 0
        if args.command == "record":
            record_event(
                repo,
                args.event_key,
                args.signal[0] if args.signal else None,
                args.completed,
                args.promoted_candidate,
            )
            print(json.dumps({"status": "recorded", "event_key": args.event_key}, ensure_ascii=False))
            return 0
        print(json.dumps(decision(repo, args.event, args.event_key, set(args.signal)), ensure_ascii=False, indent=2))
        return 0
    except LoopError as exc:
        print(json.dumps({"status": "needs_human", "reason": "invalid_loop_state", "details": str(exc)}, ensure_ascii=False))
        return 20


if __name__ == "__main__":
    sys.exit(main())
