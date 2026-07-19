#!/usr/bin/env python3
"""Deterministic AI-readiness context gate.

Checks Markdown links, module context coverage, context freshness, and static
eval-case structure without requiring an external model or third-party package.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
POLICY_PATH = ROOT / ".agent-os/ai-readiness.yml"
SCORE_PATH = ROOT / "docs/ai-readiness-score.json"
EVALS_PATH = ROOT / "evals/context-tasks.json"
LATEST_EVAL_PATH = ROOT / "evals/results/latest.json"
MARKDOWN_LINK = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
IGNORED_LINK_PREFIXES = ("http://", "https://", "mailto:", "#")
CODE_EXTENSIONS = {".java", ".ts", ".tsx", ".js", ".jsx", ".py", ".sh", ".go", ".rs", ".kt"}


def read_policy(path: Path) -> dict[str, object]:
    policy: dict[str, object] = {
        "threshold": 75,
        "max_drift_days": 30,
        "eval_pass_rate_threshold": 0.8,
        "fail_on_broken_refs": True,
        "modules": [],
        "exclude": [],
    }
    current_list: str | None = None
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        if line.startswith("  - ") and current_list in {"modules", "exclude"}:
            policy[current_list].append(line[4:].strip())  # type: ignore[index]
            continue
        if ":" not in line:
            continue
        key, value = (part.strip() for part in line.split(":", 1))
        current_list = key if not value else None
        if key in {"threshold", "max_drift_days"} and value.isdigit():
            policy[key] = int(value)
        elif key == "eval_pass_rate_threshold":
            try:
                policy[key] = float(value)
            except ValueError:
                pass
        elif key == "fail_on_broken_refs" and value in {"true", "false"}:
            policy[key] = value == "true"
    return policy


def is_excluded(path: Path, exclusions: list[str]) -> bool:
    relative = path.relative_to(ROOT).as_posix()
    return any(relative == item or relative.startswith(item.rstrip("/") + "/") for item in exclusions)


def markdown_files(exclusions: list[str]) -> list[Path]:
    return [path for path in ROOT.rglob("*.md") if not is_excluded(path, exclusions) and ".git" not in path.parts]


def validate_links(files: list[Path]) -> list[str]:
    failures: list[str] = []
    for source in files:
        for target in MARKDOWN_LINK.findall(source.read_text(encoding="utf-8")):
            target = target.split("#", 1)[0]
            if not target or target.startswith(IGNORED_LINK_PREFIXES):
                continue
            candidate = Path(target) if target.startswith("/") else source.parent / target
            if not candidate.exists():
                failures.append(f"broken Markdown link: {source.relative_to(ROOT)} -> {target}")
    return failures


def context_file(module: Path) -> Path | None:
    for name in ("AGENTS.md", "CODEX.md", "README.md"):
        candidate = module / name
        if candidate.exists():
            return candidate
    return None


def validate_modules(modules: list[str], max_drift_days: int) -> list[str]:
    failures: list[str] = []
    now = datetime.now(timezone.utc).timestamp()
    for name in modules:
        module = ROOT / name
        context = context_file(module)
        if context is None:
            failures.append(f"missing module context: {name}/AGENTS.md, CODEX.md, or README.md")
            continue
        latest_code_mtime = max(
            (path.stat().st_mtime for path in module.rglob("*") if path.is_file() and path.suffix in CODE_EXTENSIONS),
            default=context.stat().st_mtime,
        )
        age_days = (now - context.stat().st_mtime) / 86_400
        if latest_code_mtime > context.stat().st_mtime and age_days > max_drift_days:
            failures.append(f"stale module context ({age_days:.0f}d): {context.relative_to(ROOT)}")
    return failures


def validate_evals() -> list[str]:
    if not EVALS_PATH.exists():
        return ["missing eval cases: evals/context-tasks.json"]
    try:
        payload = json.loads(EVALS_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return [f"invalid eval JSON: {error}"]
    failures: list[str] = []
    cases = payload.get("cases") if isinstance(payload, dict) else None
    if not isinstance(cases, list) or not cases:
        return ["eval cases must contain a non-empty cases array"]
    for case in cases:
        if not isinstance(case, dict) or not isinstance(case.get("id"), str):
            failures.append("eval case missing string id")
            continue
        for required in ("prompt", "expected_paths", "required_checks", "constraints", "status"):
            if not case.get(required):
                failures.append(f"eval case {case['id']} missing {required}")
        for expected_path in case.get("expected_paths", []):
            if not isinstance(expected_path, str) or not (ROOT / expected_path).exists():
                failures.append(f"eval case {case['id']} references missing path: {expected_path}")
    return failures


def validate_score(threshold: int) -> list[str]:
    if not SCORE_PATH.exists():
        return [f"missing score report: {SCORE_PATH.relative_to(ROOT)}"]
    try:
        payload = json.loads(SCORE_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return [f"invalid score JSON: {error}"]

    failures: list[str] = []
    total = payload.get("total")
    if not isinstance(total, int):
        failures.append("score report total must be an integer")
    elif total < threshold:
        failures.append(f"AI-readiness score below threshold: {total} < {threshold}")

    meta = payload.get("meta")
    if not isinstance(meta, dict):
        failures.append("score report missing meta object")
    else:
        if not isinstance(meta.get("scored_at"), str) or not meta["scored_at"]:
            failures.append("score report missing meta.scored_at")
        if not isinstance(meta.get("git_branch"), str) or not meta["git_branch"]:
            failures.append("score report missing meta.git_branch")
    return failures


def validate_eval_results(pass_rate_threshold: float) -> list[str]:
    """Validate the optional successful eval snapshot when one is published."""
    if not LATEST_EVAL_PATH.exists():
        return []
    try:
        payload = json.loads(LATEST_EVAL_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return [f"invalid eval result JSON: {error}"]

    summary = payload.get("summary")
    if not isinstance(summary, dict):
        return ["eval result missing summary object"]

    runs = summary.get("runs")
    completed = summary.get("completed_runs")
    pass_rate = summary.get("pass_rate")
    failures: list[str] = []
    if not isinstance(runs, int) or runs <= 0:
        failures.append("eval result summary.runs must be a positive integer")
    if not isinstance(completed, int) or completed != runs:
        failures.append(f"eval result incomplete: completed_runs={completed}, runs={runs}")
    if not isinstance(pass_rate, (int, float)) or not 0 <= pass_rate <= 1:
        failures.append("eval result summary.pass_rate must be between 0 and 1")
    elif pass_rate < pass_rate_threshold:
        failures.append(f"eval pass rate below threshold: {pass_rate:.0%} < {pass_rate_threshold:.0%}")
    return failures


def main() -> int:
    if not POLICY_PATH.exists():
        print(f"missing policy: {POLICY_PATH.relative_to(ROOT)}")
        return 1
    policy = read_policy(POLICY_PATH)
    exclusions = list(policy["exclude"])
    failures = validate_modules(list(policy["modules"]), int(policy["max_drift_days"]))
    failures.extend(validate_evals())
    failures.extend(validate_score(int(policy["threshold"])))
    failures.extend(validate_eval_results(float(policy["eval_pass_rate_threshold"])))
    if policy["fail_on_broken_refs"]:
        failures.extend(validate_links(markdown_files(exclusions)))
    if failures:
        print("AI-readiness gate failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print("AI-readiness gate passed: module context, freshness, Markdown references, static eval cases, score threshold, and published eval results are valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
