# 사람인 JD 이미지 OCR 폴백 API 명세

## 변경 요약

엔드포인트·요청·응답 래퍼는 **변경하지 않는다**. 기존 `POST /api/jd/fetch`(`JdFetchController`, 요청 `JdFetchRequest{jdUrl}`, 응답 `ApiResponse<JdFetchResponse>`)를 그대로 쓴다. 변경은 **서버 내부 폴백 동작**과 응답의 `fetchMode` 값 하나뿐이다: 사람인 텍스트 추출이 끝내 실패할 때 JD 본문 이미지를 Gemini 비전으로 OCR해 성공하면 `fetchMode = "image-ocr"`로 응답한다. **새 에러 코드는 추가하지 않는다.**

## 엔드포인트 (변경 없음)

- `POST /api/jd/fetch` — JD 링크에서 본문 수집.
- 요청 본문(`JdFetchRequest`): `{ "jdUrl": "https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=..." }`
- 응답: `ApiResponse<JdFetchResponse>`(`success`/`data`/`error`).

### 응답 스키마 (`JdFetchResponse`, 필드 불변)

```
{
  "jdText": "...",
  "sourceUrl": "...",
  "title": "...",
  "fetchMode": "static-html" | "image-ocr",
  "sourceSite": "saramin" | "unknown"
}
```

- `fetchMode`에 **신규 값 `image-ocr`** 가 추가된다(기존 `static-html`은 그대로). 텍스트로 추출되면 `static-html`, 이미지 OCR 폴백으로 추출되면 `image-ocr`.
- `image-ocr`로 성공할 때 `sourceSite`는 `saramin`을 유지한다.
- `jdText`는 OCR 결과를 정규화(공백 정리)하고 최소 길이 기준(`MIN_CONTENT_LENGTH=50` 감각)을 통과한 값이다.

## 서버 폴백 흐름 (신규 동작)

`JdFetchService.fetch()`의 처리 순서에 마지막 단계가 추가된다.

1. `validateUrl` — 기존 그대로(스킴·호스트, `isUnsafeHost`/`isSupportedHost`).
2. `fetchHtml` + `jdHtmlExtractor.extract()` — 텍스트 성공 시 `fetchMode = "static-html"`로 반환(OCR 미실행).
3. 텍스트 실패(`JD_FETCH_EMPTY_CONTENT`/`JD_FETCH_UNSUPPORTED_SOURCE`)이고 사람인 relay-view면 기존 `fetchSaraminFallback`(view-ajax → view-detail) 시도 — 성공 시 `static-html`.
4. **[신규] JD 이미지 OCR 폴백**: 위가 모두 실패하고 대상이 사람인이면, 이미 받은 사람인 상세 HTML에서 JD 이미지를 탐지·다운로드해 Gemini 비전으로 OCR한다. 성공하면 `fetchMode = "image-ocr"`로 `JdFetchResponse` 반환.
5. OCR도 실패하거나 건너뛰면(키 없음·후보 없음·결과 미달·내부 오류) **텍스트 추출이 원래 던진 기존 에러를 그대로 반환**한다.

## 이미지 탐지·다운로드 계약

### 탐지

- 입력: 이미 가져온 사람인 상세 HTML + 페이지 URL.
- 사람인 상세 컨테이너(`.user_content`/`.wrap_jv_cont`/`.jv_cont`) 내부 `img`에서 본문성이 가장 높은 단일 이미지 한 장을 선택한다.
- 상대 `src`는 페이지 URL 기준 `URI.resolve`로 절대화한다. `data:` URI·빈 `src`는 제외.
- 후보 없으면 OCR 건너뜀.

### 다운로드 (🔴 SSRF 보안)

- 이미지 URL 호스트를 **기존 `isUnsafeHost`와 동일 규칙**으로 검증한다(localhost·`127.0.0.0/8`·`10/8`·`172.16-31`·`192.168`·`169.254`·`0.x`·IPv6 `::1`/`fc`/`fd`/`fe80`). 위반 시 다운로드 금지.
- **신뢰 이미지 호스트 allowlist**: `saramin.co.kr` 및 그 서브도메인(예: `www.saramin.co.kr`)과 사람인 이미지 CDN 호스트만 허용한다. 구체적 CDN 호스트 목록은 구현 시 실데이터로 확정하되, **기본은 사람인 도메인 서브도메인 허용**으로 두고 그 외는 명시적 allowlist에만 추가한다. allowlist 외 호스트는 다운로드 금지(OCR 건너뜀).
- **크기 상한(확정): 8MB**. 응답 본문이 8MB를 초과하면 폐기한다(다운로드 중 누적 바이트가 상한을 넘으면 중단·폐기).
- `Content-Type`이 `image/*`가 아니면 폐기한다.
- 타임아웃: 연결 10초·요청 15초(기존 `JdFetchService` HttpClient 정책과 동일 감각).
- 리다이렉트 시 최종 도달 호스트도 위 두 검증을 통과해야 한다.

## Gemini 비전 OCR 계약 (`JdImageOcr` / `GeminiJdImageOcr`)

- OCR은 인터페이스 `JdImageOcr`로 추상화한다. 입력은 이미지 바이트(+ MIME 타입), 출력은 추출 텍스트(또는 빈 결과)다.
- Gemini 구현체는 `GeminiMatchPreviewProvider`(`backend/src/main/java/com/jdsnack/match/GeminiMatchPreviewProvider.java`)의 URI 빌드(약 90~97행)·API 키/모델 주입(약 33~59행)·HTTP 호출·상태 검사(약 61~88행) 패턴을 복제한다. 모델은 동일하게 `gemini-2.5-flash`(`GEMINI_MODEL` 오버라이드 가능).
- `generateContent` 요청 본문은 `contents:[{parts:[{inlineData:{mimeType, data(base64)}}, {text: <OCR 지시 프롬프트>}]}]` 형태다.
- OCR 지시 프롬프트: 이미지에서 보이는 텍스트만 그대로 추출(원문 언어 유지, 번역·요약·해설 금지, 마크다운 래핑 금지, 순수 텍스트만). 응답에 코드펜스가 있으면 `stripJsonFence` 동급 처리로 제거하거나 일반 텍스트로 취급한다(JSON 파싱이 아닌 텍스트 추출이므로 후처리는 정규화 위주).
- 응답에서 `candidates[0].content.parts[0].text`를 읽어 정규화한다(`GeminiMatchPreviewProvider.parseResponse` 약 148~160행과 동일한 경로).

## 키 부재·실패 정책 (graceful fallback, 새 에러 코드 없음)

- `GEMINI_API_KEY` 공백 → OCR 폴백 건너뜀, 텍스트 추출이 던진 기존 에러 반환(`GEMINI_API_KEY_MISSING`을 JD fetch에서 새로 던지지 않는다).
- 이미지 후보 없음 / allowlist 외 / 크기·타입 위반 / 다운로드 실패 → OCR 건너뜀, 기존 에러 반환.
- Gemini 호출 실패·비어있는 OCR 결과·최소 길이 미달 → OCR 결과 폐기, 기존 에러(`JD_FETCH_EMPTY_CONTENT`/`JD_FETCH_UNSUPPORTED_SOURCE`) 반환.
- 모든 실패는 기존 `ApiResponse` 에러 형태로 반환한다(`ErrorCode` 변경·추가 없음).

## 실패 응답 계약 (변경 없음)

- 기존 `ErrorCode`(`INVALID_JD_URL`, `JD_FETCH_EMPTY_CONTENT`, `JD_FETCH_UNSUPPORTED_SOURCE`, `JD_FETCH_FAILED`)를 그대로 사용한다. OCR 폴백 추가로 인한 새 코드·새 HTTP 상태는 없다.

## 경계·보안 원칙

- 경계는 `JdFetchController -> JdFetchService -> (JdHtmlExtractor | JdImageOcr) -> External`을 유지한다. OCR 추상화는 `com.jdsnack.jd` 패키지의 신규 인터페이스/구현체 책임이다.
- 이미지 다운로드의 호스트 안전성·allowlist·크기·타입·타임아웃 검증은 서버에서만 수행한다(SSRF 방어는 필수).
- 비밀 키(`GEMINI_API_KEY`)는 서버에서만 처리하며 프론트에 노출·저장하지 않는다(기존 원칙 유지).
