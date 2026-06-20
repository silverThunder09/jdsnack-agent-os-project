# 사람인 JD 이미지 OCR 폴백 요구사항

사람인 채용공고 중 상당수는 JD 본문을 **디자인된 이미지 한 장**으로 올린다. 이 경우 현재 텍스트 스크래핑(`JdHtmlExtractor`)은 본문을 찾지 못해 `JD_FETCH_EMPTY_CONTENT`/`JD_FETCH_UNSUPPORTED_SOURCE`로 실패한다. 본 기능은 **기존 텍스트 추출이 끝내 실패할 때만** JD 본문 이미지를 탐지해 OCR로 글자를 뽑아 JD 텍스트로 쓰는 **폴백**을 추가한다. OCR 엔진은 이미 쓰는 Gemini 비전(`gemini-2.5-flash`, 멀티모달 `inlineData` 입력)을 재사용하므로 새 의존성은 없다. 텍스트로 정상 추출되는 공고는 기존과 동일하게 처리되어 추가 비용이 0이다. 범위는 **사람인만**이다.

## 배경 (현재 코드)

- `backend/src/main/java/com/jdsnack/jd/JdFetchService.java`의 `fetch()`가 흐름을 총괄한다: `validateUrl`(사람인 호스트 allowlist + SSRF 차단, 약 245~333행) → `fetchHtml`(`buildPageRequest`, 응답 1MB 제한) → `jdHtmlExtractor.extract()`. 추출이 `JD_FETCH_EMPTY_CONTENT`/`JD_FETCH_UNSUPPORTED_SOURCE`로 실패하고 대상이 사람인 relay-view면 `fetchSaraminFallback`(view-ajax → iframe view-detail → direct view-detail, 약 81~109행)을 마지막으로 시도한다. **stub/fixture/ai-local 모드 분기는 없으며 항상 라이브 스크래핑이다.**
- `backend/src/main/java/com/jdsnack/jd/JdHtmlExtractor.java`는 Jsoup로 사람인 셀렉터(`.recruit_detail`/`.wrap_jv_cont`/`.jv_cont`/`.user_content` 등, 약 38~47행)에서 텍스트를 추출하고 최소 길이(`MIN_CONTENT_LENGTH=50`)·품질을 검증한다. **이미지(`img`)는 보지 않는다.**
- `backend/src/main/java/com/jdsnack/jd/JdFetchResponse.java`는 `jdText`/`sourceUrl`/`title`/`fetchMode`/`sourceSite` record다. 현재 `fetchMode` 값은 `static-html`(상수 `JdHtmlExtractor.FETCH_MODE`).
- SSRF 방어는 `JdFetchService.isUnsafeHost`(localhost·사설 IPv4·`169.254`·IPv6 ULA/링크로컬 차단, 약 282~333행)와 `isSupportedHost`(`www.saramin.co.kr`/`saramin.co.kr`만 허용, 약 277~280행)로 이미 갖춰져 있다.
- Gemini 호출 본보기는 `backend/src/main/java/com/jdsnack/match/GeminiMatchPreviewProvider.java`다: URI 빌드(약 90~97행), API 키 `@Value("${GEMINI_API_KEY:}")`(약 36행), 모델 `@Value("${GEMINI_MODEL:gemini-2.5-flash}")`, `stripJsonFence`(약 194~203행), HTTP 호출·상태 검사·예외 매핑(약 61~88행). 이미지 OCR은 `generateContent` 요청의 `parts`에 `{inlineData:{mimeType, data(base64)}}` + `{text}`를 함께 보내는 형태다.
- 프론트는 `frontend/src/services/api.ts`의 `fetchJdFromUrl()`(약 274행, `POST /api/jd/fetch`)로 결과를 받아 `JdFetchResult{jdText, fetchMode, sourceSite, ...}`(`frontend/src/types/diagnosis.ts` 약 95~103행)로 매핑한다.

## 용어 정의

- **JD 이미지 폴백(image-ocr fallback)**: 텍스트 추출(기존 `extract` + `fetchSaraminFallback`)이 끝내 실패한 사람인 공고에서, 상세 컨테이너의 JD 본문 이미지를 탐지·다운로드해 Gemini 비전으로 글자를 추출하고 그 결과를 JD 텍스트로 쓰는 마지막 폴백 단계.
- **JD 이미지 후보**: 사람인 상세 컨테이너(`.user_content`/`.wrap_jv_cont`/`.jv_cont`) 내부의 `img` 중 본문성이 높은(가장 크거나 본문 영역에 속한) 이미지.
- **신뢰 이미지 호스트**: 이미지 바이트를 가져올 수 있도록 허용한 호스트 집합. 사람인 도메인(`saramin.co.kr` 및 그 서브도메인)과 사람인이 사용하는 이미지 CDN 호스트만 포함한다. allowlist 외 호스트는 금지.

## `REQ-01` 텍스트 추출 실패 시에만 동작하는 이미지 OCR 폴백 훅

- 폴백 훅은 사람인 텍스트 추출이 **끝내 실패**한 경우(기존 `extract`가 던진 `JD_FETCH_EMPTY_CONTENT`/`JD_FETCH_UNSUPPORTED_SOURCE`, 그리고 적용 가능 시 `fetchSaraminFallback`까지 실패)에 한해, `JdFetchService.fetch()`의 **마지막 단계**로 한 번 시도한다.
- 텍스트가 충분히 추출되어 `extract`가 정상 `JdFetchResponse`를 반환하면 OCR은 **시도하지 않는다**(추가 비용 0). 텍스트 공고의 기존 동작·응답은 완전히 동일하게 유지한다.
- 폴백 대상은 **사람인 호스트(`isSupportedHost`)** 로 한정한다. 사람인 외 사이트는 OCR 폴백을 시도하지 않고 기존 에러를 그대로 던진다.

## `REQ-02` JD 이미지 탐지

- 이미지 탐지는 이미 가져온 사람인 상세 HTML(기존 `extract`/`fetchSaraminFallback`이 받은 HTML)을 재사용해 수행한다(이미지 탐지만을 위해 본문 HTML을 다시 받지 않는다).
- 사람인 상세 컨테이너(`.user_content`/`.wrap_jv_cont`/`.jv_cont`) 내부의 `img`에서 JD 본문 이미지 후보를 선정한다. 후보가 여러 개면 본문성이 가장 높은 **단일 이미지 한 장**을 선택한다(가장 크거나 본문 영역에 속한 이미지). 다중 이미지 합성 OCR은 범위 밖이다.
- 이미지 `src`가 상대경로면 페이지 URL 기준으로 **절대 URL로 resolve**한다(`URI.resolve` 사용). `data:` URI, 빈 `src`, 비-이미지 자산은 후보에서 제외한다.
- 탐지된 후보가 없으면 OCR을 건너뛰고 기존 에러를 그대로 던진다.

## `REQ-03` 🔴 SSRF 보안 (필수)

- 이미지 바이트를 가져올 때 이미지 URL **호스트를 기존 `isUnsafeHost`와 동일한 규칙으로 검증**한다(localhost·사설 IPv4·`169.254`·IPv6 ULA/링크로컬 등 차단). 임의 호스트 이미지 fetch는 금지한다.
- 허용 호스트는 **신뢰 이미지 호스트 allowlist**(사람인 도메인 + 사람인 이미지 CDN 호스트)로 한정한다. allowlist 밖 호스트의 이미지는 가져오지 않는다(OCR 건너뜀).
- 이미지 다운로드는 **크기 상한**(확정: `api-spec.md` 참조)을 강제한다. 상한 초과 응답은 폐기한다.
- 응답 `Content-Type`이 이미지(`image/*`)인지 검증하고, 아니면 폐기한다.
- 이미지 fetch에 **연결·요청 타임아웃**을 적용한다(기존 `JdFetchService` 타임아웃 정책과 일관).
- 리다이렉트가 허용되더라도 **최종 도달 호스트**가 위 두 검증(호스트 안전성 + allowlist)을 통과해야 한다.

## `REQ-04` OCR 추상화 (테스트 가능성)

- OCR을 인터페이스(예: `JdImageOcr`)로 두고, Gemini 비전 구현체(예: `GeminiJdImageOcr`)와 테스트용 fake/stub를 **주입 가능**하게 한다.
- 단위·컨트롤러 테스트가 **실제 Gemini를 호출하지 않도록** 한다(매칭 테스트가 `GeminiMatchPreviewProvider`를 HttpClient 스텁/주입으로 다루는 방식과 동일한 감각). 이미지 바이트 fetch도 주입된 `HttpClient`로 테스트에서 스텁 가능해야 한다.
- 경계는 `JdFetchService`(흐름 조율) → `JdImageOcr`(OCR 추상화) → Gemini 외부 API를 유지한다. OCR 구현 세부는 `JdFetchService`에 새지 않는다.

## `REQ-05` GEMINI_API_KEY 의존과 graceful fallback

- OCR 폴백은 Gemini 비전 구현체에 의존하므로 `GEMINI_API_KEY`(`@Value("${GEMINI_API_KEY:}")`)가 공백이면 OCR 폴백을 **건너뛰고**, 텍스트 추출이 원래 던진 기존 에러(`JD_FETCH_EMPTY_CONTENT`/`JD_FETCH_UNSUPPORTED_SOURCE`)를 그대로 반환한다. JD fetch가 새로운 방식으로 깨지지 않는다.
- OCR을 시도했으나 결과가 비었거나 최소 길이·품질 기준 미달이면, 마찬가지로 **기존 에러로 graceful fallback** 한다.
- Gemini 호출 실패·이미지 fetch 실패 등 폴백 내부 오류는 JD fetch 전체를 깨뜨리지 않고 기존 에러(`JD_FETCH_EMPTY_CONTENT` 등)로 수렴한다. **새 에러 코드는 추가하지 않는다**(기존 코드 재사용).

## `REQ-06` 응답 계약

- 이미지 OCR로 JD 텍스트 추출에 성공하면 `JdFetchResponse`를 반환하되 `fetchMode = "image-ocr"`(신규 값)로 표시한다. `sourceSite`는 `saramin`을 유지한다.
- `jdText`는 OCR 결과를 기존 정규화/최소 길이 기준(`JdHtmlExtractor`의 normalize·`MIN_CONTENT_LENGTH=50` 감각)을 재사용해 검증한 값이다. 기준 미달이면 `REQ-05`대로 기존 에러로 폴백한다.
- `ApiResponse<JdFetchResponse>` 래퍼·`POST /api/jd/fetch` 엔드포인트 형태는 변경하지 않는다.

## `REQ-07` 프론트 무변경

- 프론트는 변경하지 않는다. JD 텍스트는 기존 `fetchJdFromUrl` 흐름으로 그대로 채워진다(성공 시 `JdFetchResult.jdText`).
- `fetchMode = "image-ocr"`는 프론트가 이미 임의 문자열을 받는 `fetchMode: string` 필드로 수용하므로 타입·UI 변경이 필요 없다. "이미지에서 추출됨" 같은 표기는 범위 밖이다.

## 범위 밖

- 사람인 외 사이트의 이미지 OCR.
- 항상-OCR(텍스트가 충분히 추출돼도 OCR 수행). 본 기능은 **실패 시 폴백만**이다.
- 첨부파일(PDF) OCR, 다국어 번역, 이미지 여러 장 합성 OCR.
- 프론트 UI 변경(추출 출처 배지 등).
- 새 `ErrorCode` 추가, `ApiResponse<T>` 래퍼 변경, `POST /api/jd/fetch` 요청 스키마 변경.
- 사람인 이미지 탐지 휴리스틱 고도화(OCR 정확도 튜닝, 표/레이아웃 복원 등) — 단일 본문 이미지 한 장 OCR로 한정.
