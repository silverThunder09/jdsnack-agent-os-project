#!/usr/bin/env python3
"""Fail closed if the installed hook bundle differs from its approved Git source."""

from pathlib import Path
import os
import re
import subprocess
import sys
import tempfile

FILES = {
    "pre-commit", "pre-push", "backends.json", "scripts/verify-hook-bundle.py",
    "scripts/verify-trusted-hook-bundle-acl.ps1", "scripts/check-ai-readiness.py",
    "scripts/pre-push-ai-review.sh", "scripts/pre-push-ai-review.source", "scripts/render-reviewer.py",
    "scripts/review-policy.json", "scripts/review-risk.ps1",
    "scripts/secure-review-temp-acl.ps1", "scripts/verify-codex-auth-permissions.ps1",
    "scripts/codex-auth-permissions.ps1", "scripts/review-path-safety.ps1",
}
SOURCE_FILES = {
    "pre-commit": "scripts/trusted-hooks/pre-commit",
    "pre-push": "scripts/trusted-hooks/pre-push",
    "backends.json": "backends.json",
    "scripts/verify-hook-bundle.py": "scripts/trusted-hooks/verify-hook-bundle.py",
    "scripts/verify-trusted-hook-bundle-acl.ps1": "scripts/trusted-hooks/verify-trusted-hook-bundle-acl.ps1",
    "scripts/check-ai-readiness.py": "scripts/check-ai-readiness.py",
    "scripts/pre-push-ai-review.source": "scripts/pre-push-ai-review.sh",
    "scripts/render-reviewer.py": "scripts/trusted-hooks/render-reviewer.py",
    "scripts/review-policy.json": "scripts/review-policy.json",
    "scripts/review-risk.ps1": "scripts/review-risk.ps1",
    "scripts/secure-review-temp-acl.ps1": "scripts/secure-review-temp-acl.ps1",
    "scripts/verify-codex-auth-permissions.ps1": "scripts/verify-codex-auth-permissions.ps1",
    "scripts/codex-auth-permissions.ps1": "scripts/codex-auth-permissions.ps1",
    "scripts/review-path-safety.ps1": "scripts/review-path-safety.ps1",
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
    source_kind = read_regular(root, "trusted-source-kind").decode().strip()
    checkout_sha = read_regular(root, "checkout-sha").decode().strip()
    if not all(SHA.fullmatch(value) for value in (source_sha, trusted_sha, checkout_sha)):
        fail("invalid trusted source metadata")
    repo = Path(git(["rev-parse", "--show-toplevel"], Path.cwd()))
    if source_kind == "origin-main":
        if ref != "refs/remotes/origin/main":
            fail("origin-main metadata names an unexpected source ref")
        current_sha = git(["rev-parse", "--verify", f"{ref}^{{commit}}"], repo)
        if source_sha != trusted_sha or source_sha != current_sha:
            fail("bundle is stale or its source SHA does not match origin/main")
    elif source_kind == "approved-bootstrap":
        match = re.fullmatch(r"refs/codex/trusted-hook-bootstrap/([0-9a-f]{40,64})", ref)
        if not match or source_sha != trusted_sha or source_sha != match.group(1):
            fail("approved bootstrap metadata is malformed")
        approved_tree = git(["config", "--local", "--get", "jdsnack.trustedHookBootstrapTreeSha"], repo)
        current_tree = git(["rev-parse", "--verify", f"{ref}^{{tree}}"], repo)
        if approved_tree != source_sha or current_tree != source_sha:
            fail("bundle does not match the locally approved bootstrap tree")
    else:
        fail("unknown trusted source kind")

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
        source_file = SOURCE_FILES.get(relative)
        if source_file is not None:
            source_blob = git(["rev-parse", f"{ref}:{source_file}"], repo)
            if expected != source_blob:
                fail(f"bundle manifest does not match its approved source tree: {relative}")
    try:
        with tempfile.TemporaryDirectory(prefix="jdsnack-reviewer-") as temporary:
            rendered_path = Path(temporary) / "pre-push-ai-review.sh"
            subprocess.run(
                [
                    sys.executable,
                    str(root / "scripts/render-reviewer.py"),
                    str(root / "scripts/pre-push-ai-review.source"),
                    str(rendered_path),
                ],
                check=True,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            rendered_reviewer = rendered_path.read_bytes()
    except (OSError, subprocess.CalledProcessError):
        fail("approved reviewer source could not be rendered")
    if rendered_reviewer != read_regular(root, "scripts/pre-push-ai-review.sh"):
        fail("rendered reviewer does not match its approved source")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
