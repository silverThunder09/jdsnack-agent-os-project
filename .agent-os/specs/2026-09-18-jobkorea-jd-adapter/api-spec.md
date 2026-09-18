## API 계약

### POST /api/jd/fetch

- 요청·응답 형태는 변경하지 않는다. 요청은 `{ "jdUrl": string }`, 성공 응답은 `ApiResponse.success`의 `{ jdText, sourceUrl, title, fetchMode, sourceSite }`다.
- 허용 host: `www.saramin.co.kr`, `saramin.co.kr`, `www.jobkorea.co.kr`, `jobkorea.co.kr`. 판정은 host 기준이며 path·query 형태를 전제하지 않는다.
- `sourceSite`는 `saramin` 또는 `jobkorea`이고, 정적 본문 성공의 `fetchMode`는 `static-html`, 이미지형 공고 OCR 성공의 `fetchMode`는 `image-ocr`이다. 두 경로에서 `sourceUrl`은 요청 URL을 그대로 보존한다.
- 이미지 OCR은 source별 image container의 `img[src]`만 후보로 사용한다. JobKorea 이미지 호스트는 `jobkorea.co.kr` 및 하위 호스트만 허용하고, `http`/`https` scheme·이미지 MIME·최대 8 MiB body·최대 3회 redirect를 검사한다. 최종 URI가 allowlist 밖이면 다운로드와 OCR을 수행하지 않는다.
- 실패 계약(신규 error code 없음): `INVALID_JD_URL`(400, 형식·비 http(s) scheme·loopback/사설/링크로컬/`localhost` 차단), `JD_FETCH_UNSUPPORTED_SOURCE`(422, 비-allowlist host·본문 후보 없음·오류 페이지·fake success), `JD_FETCH_EMPTY_CONTENT`(422, 본문 50자 미만), `JD_FETCH_FAILED`(502, 비-2xx·본문 1,000,000자 초과·네트워크 오류·redirect 최종 host 위반).
- 공통 제약 유지: 요청 timeout 15초, redirect NORMAL, 응답 본문 상한 1,000,000자. JobKorea 전용 우회 요청·인증 헤더·쿠키는 추가하지 않는다.
- 오류 응답 본문에는 원문 HTML·내부 예외 메시지·secret을 넣지 않는다.

### POST /api/analysis-histories (및 `/file`)

- `jd.inputType` 허용 값에 `JOBKOREA_URL`을 추가한다. 기존 `TEXT`, `SARAMIN_URL`과 저장된 행의 의미는 변경하지 않으며 `jd_input_type`이 `VARCHAR(32)`이므로 migration은 필요하지 않다.
- `inputType`이 `SARAMIN_URL` 또는 `JOBKOREA_URL`이고 `jd.sourceUrl`이 있으면 서버가 `jd.sourceUrl`로 `/api/jd/fetch` 경로와 같은 수집 로직을 실행해 클라이언트 본문보다 정본을 우선한다.
- URL 입력 타입의 응답·저장 값에서 `sourceUrl`·`sourceSite`·`fetchMode`는 서버 수집 결과가 정본이다. 클라이언트가 보낸 `sourceSite`가 다르면 서버 값으로 대체한다.
- 이력 조회 `input`은 `sourceUrl`, `sourceSite`, `fetchMode`를 함께 반환하며, 이미지 OCR 이력은 `fetchMode=image-ocr`를 보존한다.
- 알 수 없는 `inputType`은 기존처럼 `INVALID_ANALYSIS_INPUT`(400)이다. quota·idempotency·timeout 계약은 변경하지 않는다.
- 이력 조회 응답의 `input.sourceSite`는 저장된 값을 그대로 반환하며 `saramin` 이력의 기존 표시는 유지된다.
