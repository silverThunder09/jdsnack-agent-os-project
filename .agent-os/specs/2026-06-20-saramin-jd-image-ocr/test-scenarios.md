# 사람인 JD 이미지 OCR 폴백 테스트 시나리오

테스트는 기존 `backend/src/test/java/com/jdsnack/jd/`의 패턴을 따른다. `JdFetchServiceTest`는 `HttpClient`를 Mockito `mock`으로 주입해 HTML/이미지 바이트 응답을 스텁한다(약 28~52행 패턴). OCR은 `JdImageOcr` fake를 주입하거나 OCR 구현체에 주입된 `HttpClient`를 스텁해 실제 Gemini를 호출하지 않는다(`GeminiMatchPreviewProvider` 테스트 감각).

## `TC-01` 텍스트 추출 성공 시 OCR 미실행 (회귀)

- 대응 AC: `AC-01`
- 절차: 사람인 URL에 대해 본문 텍스트가 충분한 HTML을 스텁(`JdFetchServiceTest`의 `supportedSaraminUrlReturnsFetchedResponse` 패턴). `JdImageOcr`는 호출되면 실패하게 만든 spy/fake로 주입.
- 기대 결과: `fetchMode = "static-html"`, `sourceSite = "saramin"`으로 정상 반환되고 `JdImageOcr`가 **호출되지 않는다**. 사람인 외 호스트(allowlist 외)는 OCR 없이 기존 에러로 끝난다.

## `TC-02` 텍스트 실패 시 이미지 OCR 폴백 성공

- 대응 AC: `AC-02`, `AC-03`
- 절차: 사람인 상세 컨테이너(`.user_content`)에 본문 텍스트는 없고 `img` 한 장만 있는 HTML을 스텁해 `extract`가 `JD_FETCH_EMPTY_CONTENT`/`UNSUPPORTED_SOURCE`로 실패하게 한다. 이미지 바이트 요청에는 유효 이미지 바이트(`Content-Type: image/png`)를 스텁. `JdImageOcr` fake가 충분한 길이의 텍스트를 반환.
- 기대 결과: `fetchMode = "image-ocr"`, `sourceSite = "saramin"`, `jdText`가 OCR fake 결과를 정규화한 값(최소 길이 통과)으로 반환된다.

## `TC-03` JD 이미지 탐지 규칙

- 대응 AC: `AC-03`
- 절차: (a) 상대경로 `src`(`/image/jd123.png`) 이미지가 상세 컨테이너에 있는 HTML, (b) `img`가 없거나 `data:` URI/빈 `src`만 있는 HTML을 각각 스텁.
- 기대 결과: (a) 상대경로가 페이지 URL 기준 절대 URL로 resolve되어 그 호스트로 이미지 다운로드가 시도된다. (b) 후보가 없어 OCR을 건너뛰고 기존 에러가 반환된다.

## `TC-04` SSRF 보안 — 호스트 안전성·allowlist 차단

- 대응 AC: `AC-04`
- 절차: 이미지 `src`가 (a) 사설/localhost 호스트(`http://127.0.0.1/x.png`, `http://10.0.0.5/x.png`), (b) allowlist 밖 임의 외부 호스트(`https://evil.example.com/x.png`)인 HTML을 스텁.
- 기대 결과: 두 경우 모두 이미지 다운로드가 시도되지 않고(`HttpClient`로 해당 호스트 요청이 나가지 않음) OCR을 건너뛰며 기존 에러가 반환된다. `isUnsafeHost`와 동일한 차단 규칙이 적용됨을 확인한다.

## `TC-05` SSRF 보안 — 크기 상한·Content-Type 검증

- 대응 AC: `AC-04`
- 절차: allowlist 통과 호스트에서 (a) 8MB 초과 바이트, (b) `Content-Type: text/html`(비-이미지) 응답을 각각 스텁.
- 기대 결과: 두 경우 모두 이미지 바이트가 폐기되어 OCR로 넘어가지 않고 기존 에러가 반환된다.

## `TC-06` OCR 추상화·테스트 격리

- 대응 AC: `AC-05`
- 절차: `JdImageOcr` fake를 주입한 `JdFetchService` 단위 테스트와, `GeminiJdImageOcr`에 주입된 `HttpClient` 스텁으로 `generateContent` 응답(`candidates[0].content.parts[0].text`)을 흉내내는 단위 테스트(`GeminiJdImageOcrTest`)를 둔다.
- 기대 결과: 두 테스트 모두 실제 Gemini 네트워크 호출 없이 통과한다. `GeminiJdImageOcr`가 `inlineData`(base64) + 텍스트 프롬프트로 요청을 구성하고 응답 텍스트를 추출함을 검증한다.

## `TC-07` GEMINI_API_KEY 부재 시 graceful fallback

- 대응 AC: `AC-06`
- 절차: `GEMINI_API_KEY`를 공백으로 둔 `GeminiJdImageOcr`(또는 키 없음을 표현하는 OCR 구현)로, 텍스트 추출이 실패한 사람인 공고를 호출.
- 기대 결과: OCR 폴백을 건너뛰고 텍스트 추출이 원래 던진 기존 에러(`JD_FETCH_EMPTY_CONTENT`/`JD_FETCH_UNSUPPORTED_SOURCE`)가 그대로 반환된다. `GEMINI_API_KEY_MISSING`이 JD fetch에서 새로 등장하지 않는다.

## `TC-08` OCR 결과 미달·내부 오류 시 폴백

- 대응 AC: `AC-06`
- 절차: (a) `JdImageOcr`가 빈 문자열/최소 길이 미만을 반환, (b) `JdImageOcr`가 예외를 던지거나 이미지 다운로드 호출이 실패하는 경우를 각각 스텁.
- 기대 결과: 모든 경우 JD fetch가 깨지지 않고 텍스트 추출이 던진 기존 에러로 수렴한다. 새 `ErrorCode`가 등장하지 않는다.

## `TC-09` 응답 계약·프론트 무변경·게이트 종합

- 대응 AC: `AC-07`
- 절차: 컨트롤러 레벨(`JdFetchControllerTest` 패턴, MockMvc)에서 OCR 폴백 성공 경로를 호출해 `ApiResponse<JdFetchResponse>` 직렬화 형태를 확인한다. `frontend/src`에 변경이 없음을 확인한다. 검증 게이트: `cd backend && ./gradlew test`, `cd frontend && npm run lint && npm test && npm run build && npm run test:e2e`.
- 기대 결과: 응답에 `fetchMode: "image-ocr"`가 포함되고 필드 집합·요청 스키마가 변경되지 않는다. 프론트 테스트(lint/test/build/e2e)가 프론트 변경 없이 그대로 통과한다(`fetchMode: string`이 신규 값을 수용). 백엔드 테스트가 통과한다.
