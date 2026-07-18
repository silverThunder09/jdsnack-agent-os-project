#!/usr/bin/env bash

set -euo pipefail

FRONTEND_URL="${FRONTEND_URL:-http://localhost:5173}"
BACKEND_URL="${BACKEND_URL:-http://localhost:8080}"
VALID_RESUME_TEXT="${VALID_RESUME_TEXT:-Experienced backend engineer with Spring Boot REST API development, validation handling, and test automation delivery across projects.}"
SHORT_RESUME_TEXT="${SHORT_RESUME_TEXT:-짧은 이력서입니다.}"
UNKNOWN_RESUME_TEXT="${UNKNOWN_RESUME_TEXT:-Platform engineer with distributed tracing rollout, incident command ownership, and multi-region disaster recovery practice across services.}"
SMOKE_TMP_DIR="${SMOKE_TMP_DIR:-/tmp/jdsnack-smoke}"
SMOKE_COOKIE_JAR="${SMOKE_COOKIE_JAR:-/tmp/jdsnack-smoke.cookies}"

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

run_smoke_login() {
  local http_code

  http_code="$(
    curl -sS -o /tmp/jdsnack-smoke-login.json -w '%{http_code}' \
      -c "${SMOKE_COOKIE_JAR}" \
      -X POST "${BACKEND_URL}/internal/test-auth/session"
  )"

  if [[ "${http_code}" != "204" ]]; then
    echo "Expected 204 for smoke session creation, got ${http_code}"
    cat /tmp/jdsnack-smoke-login.json
    return 1
  fi
}

run_authenticated_session_check() {
  curl -fsS "${FRONTEND_URL}/api/auth/session" \
    -b "${SMOKE_COOKIE_JAR}" \
    >/tmp/jdsnack-authenticated-session.json
  assert_contains /tmp/jdsnack-authenticated-session.json '"authenticated":true' "smoke session must authenticate"
}

run_short_resume_check() {
  local http_code

  http_code="$(
    curl -sS -o /tmp/jdsnack-short.json -w '%{http_code}' \
      -b "${SMOKE_COOKIE_JAR}" \
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
      -b "${SMOKE_COOKIE_JAR}" \
      -X POST "${FRONTEND_URL}/api/diagnose" \
      -H 'Content-Type: application/json' \
      -H 'Accept: application/json' \
      -d "{\"resumeText\":\"${VALID_RESUME_TEXT}\"}"
  )"

  if [[ "${http_code}" != "200" ]]; then
    echo "Expected 200 for fixture valid resume, got ${http_code}"
    cat /tmp/jdsnack-valid.json
    return 1
  fi

  assert_contains /tmp/jdsnack-valid.json '"score":78' "valid resume must return fixture score"
  assert_contains /tmp/jdsnack-valid.json '"summary":"백엔드 중심 경험은 분명하지만 성과 수치가 더 필요합니다."' "valid resume must return fixture summary"
}

prepare_upload_fixtures() {
  mkdir -p "${SMOKE_TMP_DIR}"

  VALID_RESUME_TEXT="${VALID_RESUME_TEXT}" UNKNOWN_RESUME_TEXT="${UNKNOWN_RESUME_TEXT}" SMOKE_TMP_DIR="${SMOKE_TMP_DIR}" python3 - <<'PY'
import os
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

valid = os.environ["VALID_RESUME_TEXT"]
unknown = os.environ["UNKNOWN_RESUME_TEXT"]
out = Path(os.environ["SMOKE_TMP_DIR"])
out.mkdir(parents=True, exist_ok=True)

def write_pdf(path: Path, text: str) -> None:
    escaped = text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
    stream = "BT /F1 12 Tf 50 700 Td (" + escaped + ") Tj ET"
    objects = [
        "1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n",
        "2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n",
        "3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 5 0 R /Resources << /Font << /F1 4 0 R >> >> >> endobj\n",
        "4 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj\n",
        f"5 0 obj << /Length {len(stream)} >> stream\n{stream}\nendstream endobj\n",
    ]
    content = "%PDF-1.4\n"
    offsets = []
    for obj in objects:
        offsets.append(len(content.encode("latin-1")))
        content += obj
    xref = len(content.encode("latin-1"))
    content += f"xref\n0 {len(objects) + 1}\n0000000000 65535 f \n"
    for offset in offsets:
        content += f"{offset:010d} 00000 n \n"
    content += f"trailer << /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n"
    path.write_bytes(content.encode("latin-1"))

def write_docx(path: Path, text: str) -> None:
    content_types = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>"""
    rels = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>"""
    document = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>{text}</w:t></w:r></w:p>
  </w:body>
</w:document>"""
    with ZipFile(path, "w", ZIP_DEFLATED) as zip_file:
        zip_file.writestr("[Content_Types].xml", content_types)
        zip_file.writestr("_rels/.rels", rels)
        zip_file.writestr("word/document.xml", document)

write_pdf(out / "resume.pdf", valid)
write_docx(out / "resume.docx", valid)
write_docx(out / "unknown.docx", unknown)
(out / "resume.txt").write_text(valid, encoding="utf-8")
(out / "broken.pdf").write_text("not-a-pdf", encoding="utf-8")
PY
}

run_upload_check() {
  local name="$1"
  local file_path="$2"
  local content_type="$3"
  local expected_http_code="$4"
  local response_file="$5"

  local http_code
  http_code="$(
    curl -sS -o "${response_file}" -w '%{http_code}' \
      -b "${SMOKE_COOKIE_JAR}" \
      -F "resumeFile=@${file_path};type=${content_type}" \
      "${FRONTEND_URL}/api/diagnose/file"
  )"

  if [[ "${http_code}" != "${expected_http_code}" ]]; then
    echo "Expected ${expected_http_code} for ${name}, got ${http_code}"
    cat "${response_file}"
    return 1
  fi
}

run_pdf_upload_check() {
  run_upload_check \
    "pdf upload" \
    "${SMOKE_TMP_DIR}/resume.pdf" \
    "application/pdf" \
    "200" \
    /tmp/jdsnack-pdf.json
  assert_contains /tmp/jdsnack-pdf.json '"score":78' "pdf upload must return fixture score"
}

run_docx_upload_check() {
  run_upload_check \
    "docx upload" \
    "${SMOKE_TMP_DIR}/resume.docx" \
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" \
    "200" \
    /tmp/jdsnack-docx.json
  assert_contains /tmp/jdsnack-docx.json '"score":78' "docx upload must return fixture score"
}

run_unsupported_upload_check() {
  run_upload_check \
    "unsupported upload" \
    "${SMOKE_TMP_DIR}/resume.txt" \
    "text/plain" \
    "400" \
    /tmp/jdsnack-upload-txt.json
  assert_contains /tmp/jdsnack-upload-txt.json '"code":"UNSUPPORTED_FILE_TYPE"' "txt upload must return UNSUPPORTED_FILE_TYPE"
}

run_broken_pdf_check() {
  run_upload_check \
    "broken pdf upload" \
    "${SMOKE_TMP_DIR}/broken.pdf" \
    "application/pdf" \
    "400" \
    /tmp/jdsnack-broken-pdf.json
  assert_contains /tmp/jdsnack-broken-pdf.json '"code":"FILE_TEXT_EXTRACTION_FAILED"' "broken pdf must return FILE_TEXT_EXTRACTION_FAILED"
}

run_unknown_fixture_check() {
  run_upload_check \
    "unknown fixture upload" \
    "${SMOKE_TMP_DIR}/unknown.docx" \
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" \
    "404" \
    /tmp/jdsnack-unknown-docx.json
  assert_contains /tmp/jdsnack-unknown-docx.json '"code":"FIXTURE_NOT_FOUND"' "unknown docx must return FIXTURE_NOT_FOUND"
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
  run_smoke_login
  run_authenticated_session_check
  run_short_resume_check
  run_valid_resume_check
  prepare_upload_fixtures
  run_pdf_upload_check
  run_docx_upload_check
  run_unsupported_upload_check
  run_broken_pdf_check
  run_unknown_fixture_check

  echo "Smoke test passed"
}

main "$@"
