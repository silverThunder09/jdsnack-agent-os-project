#!/usr/bin/env python3
"""Run context-planning evals with Codex CLI and store comparable metrics.

The runner is read-only: it asks an agent for a change plan and compares its
reported paths, checks, and constraints with the local eval-case oracle. It
does not ask the agent to edit files or run builds.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
CASES_PATH = ROOT / "evals/context-tasks.json"
SCHEMA_PATH = ROOT / "evals/context-plan.schema.json"
RESULTS_DIR = ROOT / "evals/results"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run read-only Codex context evals.")
    parser.add_argument("--case", action="append", dest="case_ids", help="Run one case id; repeatable")
    parser.add_argument("--variant", choices=("context-on", "context-off", "all"), default="all")
    parser.add_argument("--model", help="Optional Codex model override")
    parser.add_argument("--timeout", type=int, default=600, help="Per-run timeout in seconds")
    parser.add_argument("--dry-run", action="store_true", help="Print selected cases without calling Codex")
    return parser.parse_args()


def load_cases(case_ids: list[str] | None) -> list[dict[str, Any]]:
    payload = json.loads(CASES_PATH.read_text(encoding="utf-8"))
    cases = payload.get("cases", [])
    if case_ids:
        selected = [case for case in cases if case.get("id") in set(case_ids)]
        missing = sorted(set(case_ids) - {case.get("id") for case in selected})
        if missing:
            raise ValueError(f"unknown eval case: {', '.join(missing)}")
        return selected
    return cases


def prompt_for(case: dict[str, Any], variant: str) -> str:
    context_instruction = (
        "Start by reading AGENTS.md, the relevant module README, architecture docs, and active spec before planning."
        if variant == "context-on"
        else "Do not read AGENTS.md, README files, docs/, .agent-os/, or evals/; infer only from source layout and code names."
    )
    return f"""You are a read-only planning evaluator. Do not edit files, run builds, or use the network.
{context_instruction}

Task: {case['prompt']}

Inspect only what the variant allows, then return the required JSON schema. List likely repository-relative paths,
verification commands you would run, every constraint you would preserve, any clarification questions, and a brief plan.
Do not mention this evaluation harness or guess hidden expected answers."""


def extract_final_message(events: list[dict[str, Any]]) -> str | None:
    for event in reversed(events):
        item = event.get("item")
        if isinstance(item, dict) and item.get("type") == "agent_message":
            text = item.get("text")
            if isinstance(text, str):
                return text
        if event.get("type") in {"agent_message", "response.completed"}:
            text = event.get("text") or event.get("message")
            if isinstance(text, str):
                return text
    return None


def extract_usage(value: Any) -> dict[str, int]:
    totals = {"input_tokens": 0, "output_tokens": 0, "total_tokens": 0}

    def visit(node: Any) -> None:
        if isinstance(node, dict):
            for key in totals:
                candidate = node.get(key)
                if isinstance(candidate, int):
                    totals[key] = max(totals[key], candidate)
            for child in node.values():
                visit(child)
        elif isinstance(node, list):
            for child in node:
                visit(child)

    visit(value)
    if not totals["total_tokens"]:
        totals["total_tokens"] = totals["input_tokens"] + totals["output_tokens"]
    return totals


def command_match(expected: str, reported: list[str]) -> bool:
    normalized = expected.replace(" ", "")
    return any(normalized in command.replace(" ", "") for command in reported)


def path_match(expected: str, reported: list[str]) -> bool:
    return expected in reported


def score_case(case: dict[str, Any], response: dict[str, Any]) -> dict[str, Any]:
    paths = response.get("likely_paths", [])
    checks = response.get("verification_commands", [])
    constraints = response.get("constraints_acknowledged", [])
    expected_paths = case["expected_paths"]
    expected_checks = case["required_checks"]
    expected_constraints = case["constraints"]
    path_hits = [path for path in expected_paths if path_match(path, paths)]
    check_hits = [check for check in expected_checks if command_match(check, checks)]
    constraint_hits = [constraint for constraint in expected_constraints if constraint in constraints]
    path_rate = len(path_hits) / len(expected_paths)
    check_rate = len(check_hits) / len(expected_checks)
    constraint_rate = len(constraint_hits) / len(expected_constraints)
    return {
        "status": "pass" if path_rate >= 0.8 and check_rate == 1 and constraint_rate == 1 else "fail",
        "path_hits": path_hits,
        "path_rate": path_rate,
        "check_hits": check_hits,
        "check_rate": check_rate,
        "constraint_hits": constraint_hits,
        "constraint_rate": constraint_rate,
        "clarification_count": len(response.get("clarifications", [])),
        "reported": response,
    }


def run_case(case: dict[str, Any], variant: str, args: argparse.Namespace) -> dict[str, Any]:
    command = [
        "codex",
        "exec",
        "--ephemeral",
        "--json",
        "--sandbox",
        "read-only",
        "--output-schema",
        str(SCHEMA_PATH),
        "--cd",
        str(ROOT),
    ]
    if variant == "context-off":
        command.append("--ignore-rules")
    if args.model:
        command.extend(["--model", args.model])
    command.append(prompt_for(case, variant))
    completed = subprocess.run(command, text=True, capture_output=True, timeout=args.timeout, check=False)
    events: list[dict[str, Any]] = []
    for line in completed.stdout.splitlines():
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    final_message = extract_final_message(events)
    result: dict[str, Any] = {
        "case_id": case["id"],
        "variant": variant,
        "exit_code": completed.returncode,
        "tool_calls": sum(1 for event in events if event.get("type") == "item.completed" and event.get("item", {}).get("type") == "command_execution"),
        "usage": extract_usage(events),
    }
    if completed.returncode or not final_message:
        result.update({"status": "runner-error", "stderr": completed.stderr[-4000:]})
        return result
    try:
        response = json.loads(final_message)
    except json.JSONDecodeError:
        result.update({"status": "invalid-response", "final_message": final_message})
        return result
    result.update(score_case(case, response))
    return result


def summarize(results: list[dict[str, Any]]) -> dict[str, Any]:
    completed = [result for result in results if result["status"] in {"pass", "fail"}]
    return {
        "runs": len(results),
        "completed_runs": len(completed),
        "pass_rate": sum(result["status"] == "pass" for result in completed) / len(completed) if completed else 0,
        "mean_path_rate": sum(result.get("path_rate", 0) for result in completed) / len(completed) if completed else 0,
        "mean_check_rate": sum(result.get("check_rate", 0) for result in completed) / len(completed) if completed else 0,
        "mean_constraint_rate": sum(result.get("constraint_rate", 0) for result in completed) / len(completed) if completed else 0,
        "mean_tool_calls": sum(result.get("tool_calls", 0) for result in completed) / len(completed) if completed else 0,
        "mean_tokens": sum(result.get("usage", {}).get("total_tokens", 0) for result in completed) / len(completed) if completed else 0,
        "mean_clarifications": sum(result.get("clarification_count", 0) for result in completed) / len(completed) if completed else 0,
    }


def main() -> int:
    args = parse_args()
    if not shutil.which("codex"):
        print("Codex CLI was not found on PATH.", file=sys.stderr)
        return 2
    cases = load_cases(args.case_ids)
    variants = ["context-on", "context-off"] if args.variant == "all" else [args.variant]
    if args.dry_run:
        print(json.dumps({"cases": [case["id"] for case in cases], "variants": variants}, ensure_ascii=False))
        return 0
    results = [run_case(case, variant, args) for case in cases for variant in variants]
    payload = {
        "version": 1,
        "runner": "codex exec --sandbox read-only",
        "scored_at": datetime.now(timezone.utc).isoformat(),
        "results": results,
        "summary": summarize(results),
        "limitations": [
            "This measures read-only task planning, not implementation correctness.",
            "Context-off is a constrained source-only comparison, not a guarantee that all agent instructions are absent.",
            "Rework and human intervention require external issue/PR telemetry and are not measured here."
        ]
    }
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    output = RESULTS_DIR / f"context-plan-{datetime.now().strftime('%Y%m%dT%H%M%SZ')}.json"
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if payload["summary"]["completed_runs"] == len(results):
        (RESULTS_DIR / "latest.json").write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    print(f"AI-readiness eval results: {output.relative_to(ROOT)}")
    print(json.dumps(payload["summary"], ensure_ascii=False))
    return 0 if payload["summary"]["completed_runs"] == len(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
