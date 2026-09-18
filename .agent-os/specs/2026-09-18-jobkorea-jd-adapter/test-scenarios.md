## 테스트 시나리오

JobKorea 실호출 없이 커밋된 fixture와 mock `HttpClient`로 검증한다. fixture는 `backend/src/test/resources/jd/fixtures/`에 두고 개인정보·인증정보를 포함하지 않는다.

- TC-01: `jobkorea-backend-engineer.html` fixture로 `sourceSite=jobkorea`, `fetchMode=static-html`, `sourceUrl` 보존과 본문 추출을 확인한다.
- TC-02: 기존 사람인 fixture 회귀 — `sourceSite=saramin` 성공과 ajax/detail fallback 경로가 유지되는지 확인한다.
- TC-03: `jobkorea-noise-heavy.html` fixture에서 광고·추천공고·유사공고·네비게이션·푸터·지원 버튼 문구가 `jdText`에 없고 담당업무/자격요건 문장은 남는지 확인한다.
- TC-04: `jobkorea-empty-content.html` fixture가 `JD_FETCH_EMPTY_CONTENT`(422)를 반환하는지 확인한다.
- TC-05: `jobkorea-error-page.html` fixture가 `JD_FETCH_UNSUPPORTED_SOURCE`(422)를 반환하고 오류 안내 문구를 JD 본문으로 반환하지 않는지 확인한다.
- TC-06: 비-allowlist 호스트(예: `https://example.com/jobs/1`)가 `JD_FETCH_UNSUPPORTED_SOURCE`(422)인지 확인한다.
- TC-07: `http://127.0.0.1/x`, `http://10.0.0.5/x`, `http://169.254.169.254/x`, `http://localhost/x`, `file:///etc/passwd`, 형식 오류 URL이 `INVALID_JD_URL`(400)이고 `HttpClient.send`가 호출되지 않는지 확인한다.
- TC-08: mock 응답 500과 네트워크 `IOException`이 `JD_FETCH_FAILED`(502)인지 확인한다.
- TC-09: 본문이 1,000,000자를 초과하는 mock 응답이 `JD_FETCH_FAILED`(502)인지 확인한다.
- TC-10: redirect 결과 최종 host가 비-allowlist인 mock 응답에서 본문을 추출하지 않고 실패 계약으로 응답하는지 확인한다.
- TC-11: JobKorea URL 입력 분석 이력 생성이 `jdInputType=JOBKOREA_URL`, `sourceSite=jobkorea`, 서버 수집 `sourceUrl`로 저장되고 클라이언트가 보낸 다른 `sourceSite`가 무시되는지 확인한다.
- TC-12: 기존 `SARAMIN_URL` 이력의 생성·조회 계약이 깨지지 않는지 확인한다.
- TC-13: frontend가 JobKorea/사람인/링크 없음 입력에서 각각 `JOBKOREA_URL`·`SARAMIN_URL`·`TEXT`와 대응 `sourceSite`를 전송하는지 확인한다.
- TC-14: frontend가 `JD_FETCH_UNSUPPORTED_SOURCE`·`JD_FETCH_EMPTY_CONTENT`·`JD_FETCH_FAILED`·`INVALID_JD_URL` 안내를 구분해 표시하고 지원 사이트 문구에 JobKorea가 포함되는지 확인한다.

게이트는 `cd backend && ./gradlew test`, `cd frontend && npm run lint`, `npm test`, `npm run build`, `python scripts/check-ai-readiness.py`, PR CI다. Docker 미설치 환경에서는 Compose/health 검증을 실행하지 않고 사유를 기록한다.
