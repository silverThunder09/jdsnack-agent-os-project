# 문장 첨삭(맞춤 첨삭, 문장 단위) API 명세

## 변경 요약

신규 전용 엔드포인트 `POST /api/sentence/preview`를 추가한다. 키워드처럼 매칭 응답에 얹지 않고 분리하는 이유는 LLM 부하가 크고 단독 호출되어야 하기 때문이다. 요청 형태는 매칭(`MatchPreviewRequest`)과 동일하고, 검증·`ErrorCode` 체계·`ApiResponse<T>` 래퍼를 재사용한다. **새 에러 코드는 추가하지 않는다.**

## 신규 엔드포인트

- `POST /api/sentence/preview` — 이력서 문장 첨삭 미리보기

### 요청 본문 (`SentencePreviewRequest`)

매칭 요청과 동일한 형태다.

```
{
  "resumeSource": { "type": "TEXT" | "FILE", "value": "..." },
  "jdText": "...",
  "jdUrl": "..."   // 선택
}
```

- 매칭과 동일한 검증을 재사용한다: 이력서/JD 길이 50~10,000자, JD URL 검증(`jdUrl` 존재 시).

### 응답 스키마 (`SentencePreviewResponse`)

```
{
  "edits": [
    { "original": "이력서 원문 문장", "improved": "JD에 맞춰 개선한 문장", "reason": "개선 사유(한국어)" }
  ]
}
```

- `edits`는 항상 직렬화된다. 값이 없으면 빈 배열(`[]`)이며 null이 아니다.
- 각 항목(`SentenceEdit`)은 `original`/`improved`/`reason` 세 문자열 필드를 가진다.
- 응답은 `ApiResponse<SentencePreviewResponse>` 형태(`success`/`data`/`error`)로 감싼다(매칭과 동일).

## 항목 수 상한

- `edits` 항목 수 상한은 **최대 8건**으로 확정한다(매칭의 `MAX_KEYWORDS=8` 기준선과 동일 감각). 상한을 넘는 항목은 잘라낸다(앞에서부터 8건).

## 모드별 산출 규칙

모드 분기는 매칭과 동일하게 서비스(`SentencePreviewService`)가 담당한다. `stub`/`fixture`는 외부 호출 없이 결정적 결과를, `ai-local`만 Gemini로 분기한다.

### stub / fixture (`SentencePreviewService`)

- 외부 호출 없이 결정적인 고정/모의 `edits`를 반환한다.
- 동일 입력에 대해 결정적 결과(같은 이력서·JD → 같은 `edits`)를 보장한다.
- 상한(8건)·필드 존재(빈 리스트 보장)·null 아님 계약을 그대로 만족한다.

### ai-local (`GeminiSentencePreviewProvider`)

- 프롬프트는 매칭의 `GeminiMatchPreviewProvider.prompt()`(`backend/src/main/java/com/jdsnack/match/GeminiMatchPreviewProvider.java` 약 105~145행) 구조를 복제하되, 출력 스키마를 다음으로 둔다(JSON-only·한국어, 마크다운 래핑 금지):

```
{
  "edits": [
    { "original": "resume sentence", "improved": "improved Korean sentence aligned to JD", "reason": "why it was improved (Korean)" }
  ]
}
```

- 프롬프트 규칙에 "JD에 맞춰 이력서 문장을 개선, 최대 8건, 각 항목은 original/improved/reason을 모두 포함, JSON only" 지침을 추가한다.
- 응답 파싱은 `stripJsonFence`를 재사용해 JSON을 추출하고 `edits` 배열을 읽는다(각 객체의 `original`/`improved`/`reason`을 문자열로 매핑).
- **`edits` 필드 검증 정책(확정: 관대 처리)**: `edits`가 누락/비배열이면 빈 리스트로 채우고 성공 응답을 유지한다. 개별 항목에서 일부 필드가 비어 있어도(빈 문자열) 항목을 살린다(빈 문자열로 둠). 응답 본문 자체가 JSON으로 파싱 불가하거나 Gemini 호출이 실패한 경우에만 기존 `GEMINI_API_RESPONSE_INVALID`/`GEMINI_API_REQUEST_FAILED` 정책을 따른다.

## 실패 응답 계약 (변경 없음)

- 기존 검증·에러 코드(`EMPTY_RESUME`, `TEXT_TOO_SHORT`, `TEXT_TOO_LONG`, `EMPTY_JD`, `JD_TEXT_TOO_SHORT`, `JD_TEXT_TOO_LONG`, `INVALID_JD_URL`, `GEMINI_API_KEY_MISSING`, `GEMINI_API_REQUEST_FAILED`, `GEMINI_API_RESPONSE_INVALID`)를 그대로 사용한다. 새 에러 코드는 추가하지 않는다.
- 모든 실패는 매칭과 동일하게 `ApiResponse` 에러 형태로 반환한다.

## 경계·보안 원칙

- 경계는 `Controller -> Service -> External API`를 유지한다. 문장 첨삭은 신규 패키지 `com.jdsnack.sentence`의 서비스/프로바이더 계층 책임이다.
- 검증(`validateRequest`)·헬퍼(`stripJsonFence`)는 매칭과 동일 정책을 재사용한다(중복 구현이 아닌 동일 정책 적용; 재사용 방식은 구현 시 Codex가 결정).
- 비밀 키 등 민감정보는 서버에서만 처리하며 프론트에 저장·노출하지 않는다(기존 원칙 유지).
