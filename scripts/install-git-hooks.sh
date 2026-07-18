#!/bin/sh
set -eu

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

git config core.hooksPath .githooks
echo "Git hooks enabled: $(git config --get core.hooksPath)"
