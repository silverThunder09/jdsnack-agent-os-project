#!/usr/bin/env bash
set -euo pipefail

readonly DEFAULT_KEYCHAIN_SERVICE="jdsnack-discord-webhook"
readonly DEFAULT_KEYCHAIN_ACCOUNT="webhook-url"
readonly DEFAULT_TIMEOUT_SECONDS="10"

SECURITY_BIN="${SECURITY_BIN:-security}"
CURL_BIN="${CURL_BIN:-curl}"
JQ_BIN="${JQ_BIN:-jq}"
KEYCHAIN_SERVICE="${JDSNACK_DISCORD_KEYCHAIN_SERVICE:-$DEFAULT_KEYCHAIN_SERVICE}"
KEYCHAIN_ACCOUNT="${JDSNACK_DISCORD_KEYCHAIN_ACCOUNT:-$DEFAULT_KEYCHAIN_ACCOUNT}"
TIMEOUT_SECONDS="${JDSNACK_DISCORD_TIMEOUT_SECONDS:-$DEFAULT_TIMEOUT_SECONDS}"
STATE_DIR="${JDSNACK_ALERT_STATE_DIR:-$HOME/Library/Application Support/JDSnack/needs-human-alerts}"
SOURCE=""
REPOSITORY=""
BRANCH=""
REASON=""
URL=""
EVENT_KEY=""

usage() {
    cat <<'USAGE'
Usage: scripts/notify-needs-human.sh --source NAME --reason CODE [--repository OWNER/REPO] [--branch NAME] [--url URL] [--event-key KEY]

Sends one best-effort Discord notification for a needs-human event.
The Discord webhook URL is read only from macOS Keychain.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --source|--reason|--repository|--branch|--url|--event-key)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            case "$1" in
                --source) SOURCE="$2" ;;
                --reason) REASON="$2" ;;
                --repository) REPOSITORY="$2" ;;
                --branch) BRANCH="$2" ;;
                --url) URL="$2" ;;
                --event-key) EVENT_KEY="$2" ;;
            esac
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
done

[ -n "$SOURCE" ] && [ -n "$REASON" ] || { usage >&2; exit 2; }

for binary in "$SECURITY_BIN" "$CURL_BIN"; do
    command -v "$binary" >/dev/null 2>&1 || exit 0
done

if ! webhook_url="$("$SECURITY_BIN" find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w 2>/dev/null)"; then
    exit 0
fi
[ -n "$webhook_url" ] || exit 0

state_file=""
state_claim_dir=""
state_claimed=false
cleanup_claim() {
    if [ "$state_claimed" = true ] && [ -n "$state_claim_dir" ]; then
        rmdir "$state_claim_dir" 2>/dev/null || true
    fi
}

if [ -n "$EVENT_KEY" ] && command -v shasum >/dev/null 2>&1; then
    event_hash="$(printf '%s' "$EVENT_KEY" | shasum -a 256 | awk '{print $1}')"
    if mkdir -p "$STATE_DIR" 2>/dev/null; then
        state_file="$STATE_DIR/$event_hash"
        [ ! -e "$state_file" ] || exit 0
        state_claim_dir="$state_file.pending"
        mkdir "$state_claim_dir" 2>/dev/null || exit 0
        state_claimed=true
        trap cleanup_claim EXIT
    fi
fi

if [ -z "$URL" ] && [ -n "$REPOSITORY" ]; then
    URL="https://github.com/$REPOSITORY/pulls"
fi
URL="${URL:-https://github.com/notifications}"

content="$(printf 'JDSnack needs-human\nsource: %s\nbranch: %s\nreason: %s' "$SOURCE" "${BRANCH:-unknown}" "$REASON")"
content="$content"$'\n'"link: $URL"

if command -v "$JQ_BIN" >/dev/null 2>&1; then
    payload="$("$JQ_BIN" -cn --arg content "$content" '{content: $content, allowed_mentions: {parse: []}}')"
else
    escaped_content="${content//\\/\\\\}"
    escaped_content="${escaped_content//\"/\\\"}"
    escaped_content="${escaped_content//$'\n'/\\n}"
    escaped_content="${escaped_content//$'\r'/\\r}"
    escaped_content="${escaped_content//$'\t'/\\t}"
    payload="{\"content\":\"$escaped_content\",\"allowed_mentions\":{\"parse\":[]}}"
fi
if ! "$CURL_BIN" \
    --fail \
    --silent \
    --show-error \
    --max-time "$TIMEOUT_SECONDS" \
    --request POST \
    --header 'Content-Type: application/json' \
    --data "$payload" \
    "$webhook_url" >/dev/null; then
    printf 'Needs-human Discord notification failed.\n' >&2
    exit 0
fi

if [ -n "$state_file" ]; then
    : > "$state_file"
    state_claimed=false
    rmdir "$state_claim_dir" 2>/dev/null || true
    trap - EXIT
fi
