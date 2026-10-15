#!/usr/bin/env python3
"""Fail closed if the installed hook bundle differs from trusted origin/main."""

from pathlib import Path
import os
import re
import subprocess
import sys

FILES = {
    "pre-commit", "pre-push", "backends.json", "scripts/verify-hook-bundle.py",
    "scripts/verify-trusted-hook-bundle-acl.ps1", "scripts/check-ai-readiness.py",
    "scripts/pre-push-ai-review.sh", "scripts/review-policy.json", "scripts/review-risk.ps1",
    "scripts/secure-review-temp-acl.ps1", "scripts/verify-codex-auth-permissions.ps1",
    "scripts/codex-auth-permissions.ps1", "scripts/review-path-safety.ps1",
}
SHA = re.compile(r"^[0-9a-f]{40,64}$")


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: trusted hook bundle verification failed: {message}")


def read_regular(root: Path, relative: str) -> bytes:
    path = root / relative
    for parent in (path, *path.parents):
        if parent == root.parent:
            break
        if parent.is_symlink():
            fail(f"symlink is not allowed: {relative}")
    if not path.is_file():
        fail(f"file is missing: {relative}")
    return path.read_bytes()


def git(args: list[str], cwd: Path) -> str:
    env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_CONFIG_")}
    try:
        return subprocess.check_output(["git", *args], cwd=cwd, env=env, text=True).strip()
    except (OSError, subprocess.CalledProcessError) as error:
        fail(f"git {' '.join(args)} failed: {error}")


def main() -> int:
    if len(sys.argv) != 2:
        fail("bundle path is required")
    root = Path(sys.argv[1]).resolve(strict=True)
    ref = read_regular(root, "trusted-source-ref").decode().strip()
    source_sha = read_regular(root, "source-sha").decode().strip()
    trusted_sha = read_regular(root, "trusted-source-sha").decode().strip()
    checkout_sha = read_regular(root, "checkout-sha").decode().strip()
    if ref != "refs/remotes/origin/main" or not all(SHA.fullmatch(value) for value in (source_sha, trusted_sha, checkout_sha)):
        fail("invalid trusted source metadata")
    repo = Path(git(["rev-parse", "--show-toplevel"], Path.cwd()))
    current_sha = git(["rev-parse", "--verify", f"{ref}^{{commit}}"], repo)
    if source_sha != trusted_sha or source_sha != current_sha:
        fail("bundle is stale or its source SHA does not match origin/main")

    rows = read_regular(root, "bundle-manifest").decode().splitlines()
    entries: dict[str, str] = {}
    for row in rows:
        fields = row.split(" ")
        if len(fields) != 2 or fields[0] not in FILES or fields[0] in entries or not SHA.fullmatch(fields[1]):
            fail("manifest contains an invalid, duplicate, or unexpected entry")
        entries[fields[0]] = fields[1]
    if entries.keys() != FILES:
        fail("manifest file list is incomplete")
    for relative, expected in entries.items():
        read_regular(root, relative)
        actual = git(["hash-object", str(root / relative)], repo)
        if actual != expected:
            fail(f"installed file does not match its trusted digest: {relative}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
