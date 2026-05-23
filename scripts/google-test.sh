#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: ${ENV_FILE} file is required for googleTest." >&2
  echo "Create it from .env.example and set GEMINI_API_KEY." >&2
  exit 1
fi

if git ls-files --error-unmatch "${ENV_FILE}" >/dev/null 2>&1; then
  echo "ERROR: ${ENV_FILE} is tracked by git. Remove it from git before running googleTest." >&2
  exit 1
fi

if git diff --cached --name-only -- "${ENV_FILE}" | grep -q "^${ENV_FILE}$"; then
  echo "ERROR: ${ENV_FILE} is staged. Unstage it before running googleTest." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  echo "ERROR: GEMINI_API_KEY is required for googleTest." >&2
  exit 1
fi

cd backend
./gradlew googleTest
