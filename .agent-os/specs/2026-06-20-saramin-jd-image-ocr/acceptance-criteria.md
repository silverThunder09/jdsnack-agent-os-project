# 사람인 JD 이미지 OCR 폴백 수용 기준

## `AC-01` 텍스트 추출 성공 시 OCR 미실행 (회귀 보존)

- 사람인 공고가 텍스트로 정상 추출되면 `JdHtmlExtractor.extract()`가 성공해 `fetchMode = "static-html"`로 응답하고, OCR 폴백이 **호출되지 않는다**(추가 비용 0).
- 사람인 외 사이트는 OCR 폴백을 시도하지 않고 기존 에러(`JD_FETCH_UNSUPPORTED_SOURCE` 등)를 그대로 반환한다.
- 기존 텍스트 공고 응답·`fetchSaraminFallback`(view-ajax/view-detail) 동작이 변경 없이 유지된다.

## `AC-02` 텍스트 실패 시 이미지 OCR 폴백으로 JD 추출

- 사람인 텍스트 추출(+적용 가능 시 `fetchSaraminFallback`)이 끝내 실패하고 상세 컨테이너에 JD 본문 이미지가 있을 때, 이미지 OCR 폴백이 마지막 단계로 한 번 시도된다.
- OCR로 충분한 텍스트를 얻으면 `JdFetchResponse`가 `fetchMode = "image-ocr"`, `sourceSite = "saramin"`, OCR 결과를 정규화한 `jdText`(최소 길이 통과)로 반환된다.
- 응답은 기존 `ApiResponse<JdFetchResponse>` 래퍼 형태를 유지한다.

## `AC-03` JD 이미지 탐지

- 사람인 상세 컨테이너(`.user_content`/`.wrap_jv_cont`/`.jv_cont`) 내부 `img`에서 본문성이 가장 높은 단일 이미지 한 장을 후보로 선택한다.
- 상대 `src`는 페이지 URL 기준 절대 URL로 resolve된다. `data:` URI·빈 `src`는 후보에서 제외된다.
- 후보 이미지가 없으면 OCR을 건너뛰고 기존 에러를 반환한다.

## `AC-04` SSRF 보안 (필수)

- 이미지 URL 호스트가 `isUnsafeHost` 규칙(localhost·사설 IPv4·`169.254`·IPv6 ULA/링크로컬)에 걸리면 이미지를 다운로드하지 않는다(OCR 건너뜀).
- 신뢰 이미지 호스트 allowlist(사람인 도메인 서브도메인 + 사람인 이미지 CDN) 밖 호스트의 이미지는 다운로드하지 않는다.
- 이미지 응답이 크기 상한(8MB)을 초과하면 폐기한다.
- 응답 `Content-Type`이 `image/*`가 아니면 폐기한다.
- 이미지 fetch에 연결·요청 타임아웃이 적용된다. 리다이렉트 시 최종 도달 호스트도 호스트 안전성 + allowlist 검증을 통과해야 한다.

## `AC-05` OCR 추상화와 테스트 격리

- OCR은 인터페이스(`JdImageOcr`)로 추상화되고 Gemini 구현체와 테스트용 fake/stub가 주입 가능하다.
- 단위·컨트롤러 테스트가 실제 Gemini를 호출하지 않는다(OCR 인터페이스를 fake로 주입하거나 주입된 HttpClient를 스텁한다). 이미지 바이트 fetch도 테스트에서 스텁된다.
- 경계는 `JdFetchService -> JdImageOcr -> Gemini`를 유지하며 OCR 세부가 `JdFetchService`에 새지 않는다.

## `AC-06` GEMINI_API_KEY 부재·실패 시 graceful fallback (새 에러 코드 없음)

- `GEMINI_API_KEY`가 공백이면 OCR 폴백을 건너뛰고 텍스트 추출이 원래 던진 기존 에러(`JD_FETCH_EMPTY_CONTENT`/`JD_FETCH_UNSUPPORTED_SOURCE`)를 그대로 반환한다(JD fetch에서 `GEMINI_API_KEY_MISSING`을 새로 던지지 않는다).
- OCR 결과가 비었거나 최소 길이 미달이면 기존 에러로 폴백한다.
- Gemini 호출 실패·이미지 다운로드 실패 등 폴백 내부 오류가 JD fetch 전체를 깨뜨리지 않고 기존 에러로 수렴한다.
- 새 `ErrorCode`·새 HTTP 상태·`ApiResponse<T>` 래퍼 변경이 없다.

## `AC-07` 응답 계약·프론트 무변경

- 성공 응답 `JdFetchResponse`의 필드 집합(`jdText`/`sourceUrl`/`title`/`fetchMode`/`sourceSite`)이 변경되지 않으며, `fetchMode`만 신규 값 `image-ocr`를 가질 수 있다.
- `POST /api/jd/fetch` 요청 스키마(`JdFetchRequest{jdUrl}`)가 변경되지 않는다.
- 프론트 코드(`frontend/src` 전체)에 변경이 없다. `fetchMode = "image-ocr"`가 기존 `JdFetchResult.fetchMode: string` 필드로 그대로 수용되어 JD 텍스트가 기존 `fetchJdFromUrl` 흐름으로 채워진다.
