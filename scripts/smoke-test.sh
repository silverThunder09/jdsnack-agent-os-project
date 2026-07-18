#!/usr/bin/env bash

set -euo pipefail

FRONTEND_URL="${FRONTEND_URL:-http://localhost:5173}"
BACKEND_URL="${BACKEND_URL:-http://localhost:8080}"

wait_for_url() {
  local url="$1"
  local name="$2"

  for attempt in $(seq 1 30); do
    if curl -fsS "$url" >/tmp/jdsnack-smoke.out 2>/dev/null; then
      return 0
    fi

    echo "Waiting for ${name}... ${attempt}/30"
    sleep 2
  done

  echo "${name} did not become ready: ${url}"
  return 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if ! grep -q "$pattern" "$file"; then
    echo "Smoke assertion failed: ${message}"
    echo "--- response ---"
    cat "$file"
    echo "---------------"
    return 1
  fi
}

run_frontend_root_check() {
  curl -fsS "${FRONTEND_URL}" >/tmp/jdsnack-frontend-root.html
  assert_contains \
    /tmp/jdsnack-frontend-root.html \
    '<div id="root"></div>' \
    "frontend root html must include root mount node"
}

run_health_check() {
  curl -fsS "${FRONTEND_URL}/api/health" >/tmp/jdsnack-health.json
  assert_contains /tmp/jdsnack-health.json '"success":true' "health response must be success"
  assert_contains /tmp/jdsnack-health.json '"status":"UP"' "health response must include UP status"
  assert_contains /tmp/jdsnack-health.json '"service":"JDSnack"' "health response must include service name"
  assert_contains /tmp/jdsnack-health.json '"version":"1.0.0"' "health response must include version"
}

run_public_session_check() {
  curl -fsS "${FRONTEND_URL}/api/auth/session" >/tmp/jdsnack-session.json
  assert_contains /tmp/jdsnack-session.json '"success":true' "session endpoint must be public"
  assert_contains /tmp/jdsnack-session.json '"authenticated":false' "smoke test must start unauthenticated"
}

run_protected_api_auth_check() {
  local path
  local http_code

  for path in \
    /api/diagnose \
    /api/diagnose/file \
    /api/match/preview \
    /api/sentence/preview \
    /api/jd/fetch \
    /api/interview/preview \
    /api/analysis-histories; do
    http_code="$(
      curl -sS -o /tmp/jdsnack-protected.json -w '%{http_code}' \
        -X POST "${FRONTEND_URL}${path}" \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json' \
        -d '{}'
    )"

    if [[ "${http_code}" != "401" ]]; then
      echo "Expected 401 for unauthenticated ${path}, got ${http_code}"
      cat /tmp/jdsnack-protected.json
      return 1
    fi

    assert_contains \
      /tmp/jdsnack-protected.json \
      '"code":"AUTHENTICATION_REQUIRED"' \
      "${path} must require authentication"
  done
}

main() {
  wait_for_url "${BACKEND_URL}/api/health" "backend health"
  wait_for_url "${FRONTEND_URL}" "frontend root"

  run_frontend_root_check
  run_health_check
  run_public_session_check
  run_protected_api_auth_check

  echo "Smoke test passed"
}

main "$@"
