#!/usr/bin/env python3
"""Render the main reviewer with bundle-owned policy and checkout workspace paths."""

from pathlib import Path
import sys


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: render-reviewer.py SOURCE DESTINATION")
    source, destination = map(Path, sys.argv[1:])
    content = source.read_text(encoding="utf-8")
    replacements = (
        ('ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"',
         'BUNDLE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"\nROOT_DIR="$(git rev-parse --show-toplevel)"', 1),
        ('"$ROOT_DIR/backends.json"', '"$BUNDLE_ROOT/backends.json"', 2),
        ('"$ROOT_DIR/scripts/review-policy.json"', '"$BUNDLE_ROOT/scripts/review-policy.json"', 2),
        ('"$ROOT_DIR/scripts/secure-review-temp-acl.ps1"', '"$BUNDLE_ROOT/scripts/secure-review-temp-acl.ps1"', 1),
        ('"$ROOT_DIR/scripts/verify-codex-auth-permissions.ps1"', '"$BUNDLE_ROOT/scripts/verify-codex-auth-permissions.ps1"', 1),
        ('"$workspace_arg/scripts/review-risk.ps1"', '"$BUNDLE_ROOT/scripts/review-risk.ps1"', 1),
    )
    for old, new, expected in replacements:
        actual = content.count(old)
        if actual != expected:
            raise SystemExit(f"trusted reviewer drift: expected {expected} occurrence(s), found {actual}: {old}")
        content = content.replace(old, new)
    with destination.open("w", encoding="utf-8", newline="\n") as output:
        output.write(content)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
