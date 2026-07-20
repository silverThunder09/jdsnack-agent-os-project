#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

specs="$(awk '/^active_specs:/ { active=1; next } /^[^[:space:]]/ { active=0 } active && /^[[:space:]]+- / { sub(/^[[:space:]]*- /, ""); print }' .agent-os/standards/index.yml)"
active_count="$(printf '%s\n' "$specs" | sed '/^$/d' | wc -l | tr -d ' ')"
test "$active_count" -le 1 || { echo "At most one active spec is allowed; found $active_count"; exit 1; }
test -f .agent-os/product/spec-backlog.md

for spec in $specs; do
  for file in requirements.md acceptance-criteria.md test-scenarios.md traceability.md api-spec.md plan.md; do
    test -f "$spec/$file"
  done
  grep -Eq 'REQ-[0-9]{2}' "$spec/requirements.md"
  grep -Eq 'AC-[0-9]{2}' "$spec/acceptance-criteria.md"
  grep -Eq 'TC-[0-9]{2}' "$spec/test-scenarios.md"
  grep -Eq 'REQ-[0-9]{2}.*AC-[0-9]{2}.*TC-[0-9]{2}' "$spec/traceability.md"
done

for spec in $specs; do
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' EXIT
  grep -oE 'REQ-[0-9]{2}' "$spec/requirements.md" | sort -u > "$temp_dir/reqs"
  grep -oE 'AC-[0-9]{2}' "$spec/acceptance-criteria.md" | sort -u > "$temp_dir/acs"
  grep -oE 'TC-[0-9]{2}' "$spec/test-scenarios.md" | sort -u > "$temp_dir/tcs"
  grep -oE 'REQ-[0-9]{2}' "$spec/traceability.md" | sort -u > "$temp_dir/mapped-reqs"
  grep -oE 'AC-[0-9]{2}' "$spec/traceability.md" | sort -u > "$temp_dir/mapped-acs"
  grep -oE 'TC-[0-9]{2}' "$spec/traceability.md" | sort -u > "$temp_dir/mapped-tcs"
  diff -u "$temp_dir/reqs" "$temp_dir/mapped-reqs"
  diff -u "$temp_dir/acs" "$temp_dir/mapped-acs"
  diff -u "$temp_dir/tcs" "$temp_dir/mapped-tcs"
  awk -F'|' '/REQ-[0-9]{2}/ {
    req = $2; ac = $3; tc = $4; doc = $5
    gsub(/[`[:space:]]/, "", req); gsub(/[`[:space:]]/, "", ac)
    gsub(/[`[:space:]]/, "", tc); gsub(/[`[:space:]]/, "", doc)
    if (req !~ /REQ-[0-9]{2}/ || ac !~ /AC-[0-9]{2}/ || tc !~ /TC-[0-9]{2}/ || doc !~ /.md$/) {
      print "Invalid traceability row: " $0
      exit 1
    }
  }' "$spec/traceability.md"
done

while IFS= read -r path; do
  test -e "$path" || { echo "Missing indexed document: $path"; exit 1; }
done < <(grep -E '^[[:space:]]+- ' .agent-os/standards/index.yml | sed 's/^[[:space:]]*- //')

python3 scripts/check-ai-readiness.py
./scripts/pr-feedback-detector-test.sh
./scripts/notify-needs-human-test.sh
./scripts/backends-contract-test.sh
./scripts/open-issue-work-dispatcher-test.sh
./scripts/publish-codex-branch-test.sh
./scripts/create-codex-worktree-test.sh
python3 scripts/autonomous_spec_loop.py validate
./scripts/autonomous-spec-loop-test.sh

legacy_pattern='gemini-api-key|API Key 설정|API Key 입력|GeminiService|AI_SERVICE_ERROR|INVALID_API_KEY|tests\.md|testing\.md|jdsnack-agent-os-main\.zip'
if grep -R --exclude-dir=node_modules --exclude-dir=build --exclude-dir=.gradle -n -E "$legacy_pattern" AGENTS.md README.md config.yml .agent-os docs backend frontend; then
  echo "Legacy MVP reference found. Keep phase 1 no-key docs clean."
  exit 1
fi

echo "Docs harness passed"
