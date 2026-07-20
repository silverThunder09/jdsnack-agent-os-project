#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ruby -e 'require "yaml"; Dir[".github/workflows/*.yml"].each { |file| YAML.load_file(file) }'
./scripts/pr-ci-router-test.sh

echo "Workflow CI contract passed"
