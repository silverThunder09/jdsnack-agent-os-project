## 수용 기준

- AC-01: allowlist JobKorea 호스트(`www.jobkorea.co.kr`, `jobkorea.co.kr`)의 정적 HTML 요청은 200과 `sourceSite=jobkorea`, `fetchMode=static-html`, 요청 URL과 동일한 `sourceUrl`을 반환한다.
- AC-02: 사람인 요청의 기존 성공·fallback·오류 계약은 변경되지 않는다(`sourceSite=saramin` 회귀 유지).
- AC-03: 정상 JobKorea fixture에서 담당업무·자격요건·우대사항에 해당하는 본문이 50자 이상 추출되고, 커밋된 fixture 없이 통과하는 selector 규칙은 없다.
- AC-04: noise 포함 fixture에서 광고·추천공고·유사공고·네비게이션·헤더·푸터·지원 버튼 문구가 `jdText`에 남지 않는다.
- AC-05: 비-allowlist 호스트는 `JD_FETCH_UNSUPPORTED_SOURCE`(422), 본문 후보 없음·오류 페이지·fake success도 `JD_FETCH_UNSUPPORTED_SOURCE`(422)를 반환한다.
- AC-06: 본문 50자 미만은 `JD_FETCH_EMPTY_CONTENT`(422), 비-2xx·본문 1,000,000자 초과·네트워크 오류는 `JD_FETCH_FAILED`(502)를 반환한다.
- AC-07: 비-http(s) scheme, 잘못된 URL 형식, loopback·사설·링크로컬 IP, `localhost` 계열은 외부 요청 전에 `INVALID_JD_URL`(400)로 차단되고 HTTP 호출이 발생하지 않는다.
- AC-08: redirect 후 최종 호스트가 allowlist를 벗어나면 본문을 추출하지 않고 실패 계약으로 응답한다.
- AC-09: 전체 검증이 fixture와 mock `HttpClient`만으로 수행되며, 테스트·구현 경로에 JobKorea 실호출과 인증정보가 없다.
- AC-10: JobKorea URL 입력 분석 이력은 `jdInputType=JOBKOREA_URL`, `sourceSite=jobkorea`, 서버가 수집한 `sourceUrl`과 `fetchMode`로 저장되고, 클라이언트가 다른 `sourceSite`를 보내도 서버 값이 저장된다. OCR 성공 이력은 `fetchMode=image-ocr`를 보존하며 기존 `SARAMIN_URL` 이력 조회는 그대로 동작한다.
- AC-11: 프론트는 JobKorea 호스트 링크에서 `JOBKOREA_URL`/`jobkorea`, 사람인 호스트에서 `SARAMIN_URL`/`saramin`, 링크 없음에서 `TEXT`/`null`을 전송하고, 지원 사이트 안내 문구와 이미지 OCR 성공 안내를 노출한다. 실패 안내는 error code별로 구분되고 상태를 색상만으로 구분하지 않는다.
- AC-12: JobKorea image-only fixture와 mock 이미지 응답에서 OCR이 성공하면 200과 `sourceSite=jobkorea`, `fetchMode=image-ocr`, 원본 `sourceUrl`, OCR 본문을 반환한다. 텍스트 추출이 성공한 페이지에서는 OCR을 호출하지 않으며 기존 사람인 OCR 성공·실패 회귀도 유지한다.
- AC-13: JobKorea OCR 이미지가 비신뢰 호스트·loopback/사설 호스트·비이미지 MIME·8 MiB 초과 응답이거나 redirect 최종 호스트가 allowlist 밖이면 이미지를 다운로드/OCR하지 않는다. OCR 불가·실패·품질 미달은 기존 fetch error와 수동 입력 안내로 종료한다.

모든 AC는 TC와 [traceability](traceability.md)로 연결하며 backend Gradle test, frontend lint/test/build, AI readiness, PR 게이트를 통과한다. Compose/health 미검증 사유는 검증 기록에 남긴다.
