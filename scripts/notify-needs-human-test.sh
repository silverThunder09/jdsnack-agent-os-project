#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOTIFIER="$ROOT_DIR/scripts/notify-needs-human.sh"
FIXTURE_DIR="$ROOT_DIR/scripts/test-fixtures/needs-human-alert"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/jdsnack-notify-test.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

assert_eq() {
    local expected="$1"
    local actual="$2"
    local label="$3"
    if [ "$expected" != "$actual" ]; then
        printf 'FAIL: %s (expected %s, got %s)\n' "$label" "$expected" "$actual" >&2
        exit 1
    fi
}

arguments_file="$TEMP_DIR/curl-arguments"
NOTIFY_SECURITY_SCENARIO=configured \
NOTIFY_CURL_ARGUMENTS_FILE="$arguments_file" \
JDSNACK_ALERT_STATE_DIR="$TEMP_DIR/state" \
SECURITY_BIN="$FIXTURE_DIR/security" \
CURL_BIN="$FIXTURE_DIR/curl" \
bash "$NOTIFIER" \
    --source pr-feedback-detector \
    --repository fixture/repo \
    --branch codex/example \
    --reason required_checks_unknown \
    --url https://example.invalid/pull/1 \
    --event-key fixture-event

payload="$(sed -n '/^--data$/{n;p;}' "$arguments_file")"
assert_eq 'JDSnack needs-human
source: pr-feedback-detector
branch: codex/example
reason: required_checks_unknown
link: https://example.invalid/pull/1' "$(printf '%s' "$payload" | jq -r .content)" "notification content"
assert_eq '[]' "$(printf '%s' "$payload" | jq -c '.allowed_mentions.parse')" "mentions disabled"

duplicate_arguments_file="$TEMP_DIR/duplicate-curl-arguments"
NOTIFY_SECURITY_SCENARIO=configured \
NOTIFY_CURL_ARGUMENTS_FILE="$duplicate_arguments_file" \
JDSNACK_ALERT_STATE_DIR="$TEMP_DIR/state" \
SECURITY_BIN="$FIXTURE_DIR/security" \
CURL_BIN="$FIXTURE_DIR/curl" \
bash "$NOTIFIER" --source pr-feedback-detector --reason required_checks_unknown --event-key fixture-event
test ! -e "$duplicate_arguments_file"

pending_event_key="pending-event"
pending_event_hash="$(printf '%s' "$pending_event_key" | shasum -a 256 | awk '{print $1}')"
mkdir -p "$TEMP_DIR/pending-state/$pending_event_hash.pending"
pending_arguments_file="$TEMP_DIR/pending-curl-arguments"
NOTIFY_SECURITY_SCENARIO=configured \
NOTIFY_CURL_ARGUMENTS_FILE="$pending_arguments_file" \
JDSNACK_ALERT_STATE_DIR="$TEMP_DIR/pending-state" \
SECURITY_BIN="$FIXTURE_DIR/security" \
CURL_BIN="$FIXTURE_DIR/curl" \
bash "$NOTIFIER" --source pr-feedback-detector --reason required_checks_unknown --event-key "$pending_event_key"
test ! -e "$pending_arguments_file"

missing_arguments_file="$TEMP_DIR/missing-curl-arguments"
NOTIFY_SECURITY_SCENARIO=missing \
NOTIFY_CURL_ARGUMENTS_FILE="$missing_arguments_file" \
SECURITY_BIN="$FIXTURE_DIR/security" \
CURL_BIN="$FIXTURE_DIR/curl" \
bash "$NOTIFIER" --source pr-feedback-detector --reason gh_unavailable
test ! -e "$missing_arguments_file"

fallback_arguments_file="$TEMP_DIR/fallback-curl-arguments"
NOTIFY_SECURITY_SCENARIO=configured \
NOTIFY_CURL_ARGUMENTS_FILE="$fallback_arguments_file" \
SECURITY_BIN="$FIXTURE_DIR/security" \
CURL_BIN="$FIXTURE_DIR/curl" \
JQ_BIN=missing-jq \
bash "$NOTIFIER" --source pr-feedback-detector --reason jq_unavailable

fallback_payload="$(sed -n '/^--data$/{n;p;}' "$fallback_arguments_file")"
assert_eq 'https://github.com/notifications' "$(printf '%s' "$fallback_payload" | jq -r '.content | split("\n") | last | sub("^link: "; "")')" "fallback notification link"

failure_arguments_file="$TEMP_DIR/failure-curl-arguments"
failure_state_dir="$TEMP_DIR/failure-state"
set +e
NOTIFY_SECURITY_SCENARIO=configured \
NOTIFY_CURL_SCENARIO=failure \
NOTIFY_CURL_ARGUMENTS_FILE="$failure_arguments_file" \
JDSNACK_ALERT_STATE_DIR="$failure_state_dir" \
SECURITY_BIN="$FIXTURE_DIR/security" \
CURL_BIN="$FIXTURE_DIR/curl" \
bash "$NOTIFIER" --source pr-feedback-detector --reason discord_unavailable --event-key retry-after-failure
failure_exit_code=$?
set -e
assert_eq 0 "$failure_exit_code" "curl failure must not block the caller"
test -s "$failure_arguments_file"
test -z "$(rg --files "$failure_state_dir" 2>/dev/null || true)"

printf 'Needs-human notification tests passed\n'
