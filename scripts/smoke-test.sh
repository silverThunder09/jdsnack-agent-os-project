#!/usr/bin/env bash

set -euo pipefail

FRONTEND_URL="${FRONTEND_URL:-http://localhost:5173}"
BACKEND_URL="${BACKEND_URL:-http://localhost:8080}"
VALID_RESUME_TEXT="${VALID_RESUME_TEXT:-백엔드와 프론트엔드를 함께 다루며 프로젝트를 설계하고 운영한 경험이 있습니다. 사용자 흐름을 개선하고 테스트 자동화를 정리했습니다.}"
SHORT_RESUME_TEXT="${SHORT_RESUME_TEXT:-짧은 이력서입니다.}"

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

run_short_resume_check() {
  local http_code

  http_code="$(
    curl -sS -o /tmp/jdsnack-short.json -w '%{http_code}' \
      -X POST "${FRONTEND_URL}/api/diagnose" \
      -H 'Content-Type: application/json' \
      -H 'Accept: application/json' \
      -d "{\"resumeText\":\"${SHORT_RESUME_TEXT}\"}"
  )"

  if [[ "${http_code}" != "400" ]]; then
    echo "Expected 400 for short resume, got ${http_code}"
    cat /tmp/jdsnack-short.json
    return 1
  fi

  assert_contains /tmp/jdsnack-short.json '"code":"TEXT_TOO_SHORT"' "short resume must return TEXT_TOO_SHORT"
}

run_valid_resume_check() {
  local http_code

  http_code="$(
    curl -sS -o /tmp/jdsnack-valid.json -w '%{http_code}' \
      -X POST "${FRONTEND_URL}/api/diagnose" \
      -H 'Content-Type: application/json' \
      -H 'Accept: application/json' \
      -d "{\"resumeText\":\"${VALID_RESUME_TEXT}\"}"
  )"

  if [[ "${http_code}" != "501" ]]; then
    echo "Expected 501 for no-key MVP valid resume, got ${http_code}"
    cat /tmp/jdsnack-valid.json
    return 1
  fi

  assert_contains /tmp/jdsnack-valid.json '"code":"AI_ANALYSIS_NOT_ENABLED"' "valid resume must return AI_ANALYSIS_NOT_ENABLED"
}

main() {
  wait_for_url "${BACKEND_URL}/api/health" "backend health"
  wait_for_url "${FRONTEND_URL}" "frontend root"

  run_frontend_root_check
  run_health_check
  run_short_resume_check
  run_valid_resume_check

  echo "Smoke test passed"
}

main "$@"
