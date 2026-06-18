# 키워드 매칭 구조화 / 키워드 분석 옵션 해금 API 명세

## 변경 요약

새 엔드포인트는 추가하지 않는다. 기존 `POST /api/match/preview` 응답(`MatchPreviewResponse`)에 키워드 브레이크다운 필드 3개를 **하위호환으로 추가**한다. 요청 본문·`ApiResponse<T>` 래퍼·`ErrorCode` 체계는 변경하지 않는다.

## 영향 엔드포인트

- `POST /api/match/preview` — JD 적합도 미리보기 (요청 계약 불변)

요청 본문(`MatchPreviewRequest`: `resumeSource{type,value}`, `jdText`, `jdUrl`)은 그대로 유지한다.

## 응답 스키마 변경 (추가 필드)

기존 `MatchPreviewResponse`:

```
{ matchingScore, summary, strengths[], gaps[], suggestions[] }
```

확장 후(추가 필드만 표기):

```
{
  matchingScore, summary, strengths[], gaps[], suggestions[],
  matchedKeywords: string[],   // JD 키워드 중 이력서에서 직접 확인됨
  partialKeywords: string[],   // 동의어/어간/표기 변형 등 근사 확인됨
  missingKeywords: string[]    // 이력서에서 확인되지 않음
}
```

- 세 필드는 항상 직렬화된다. 값이 없으면 빈 배열(`[]`)이며 null이 아니다.
- 세 리스트는 상호 배타적이다(한 키워드는 정확히 한 분류).
- 응답은 `ApiResponse<MatchPreviewResponse>` 형태(`success`/`data`/`error`)로 감싼다(기존과 동일).

## 항목 수 상한

- 분류 합계 기준선은 현행 `MAX_KEYWORDS=8`(JD 키워드 추출 상한)을 따른다. JD에서 추출한 키워드를 세 분류로 나눈 것이므로 세 리스트 항목 수 합은 추출된 JD 키워드 수를 넘지 않는다.
- (권장) 표시 안정성을 위해 각 분류별로도 상한(예: 8)을 둔다. 최종 상한 값은 구현 시 현행 상수 재사용으로 고정한다.

## 모드별 산출 규칙

### stub / fixture (`MatchPreviewService.buildPreview`)

- 기존 `extractKeywords`로 JD 키워드와 이력서 키워드를 추출한다.
- `matchedKeywords` = JD 키워드 ∩ 이력서 키워드.
- `missingKeywords` = JD 키워드 − 이력서 키워드.
- `partialKeywords`: 토큰 정확 일치만 가능한 stub/fixture에서는 **근사 판정이 제한적**이다. **확정: partial은 빈 리스트(권장 A)** — stub/fixture는 matched/missing만 정확히 제공하고, 동의어 사전이 없으므로 거짓 partial을 만들지 않는다. (부분 문자열/접두 일치는 잡음 위험으로 채택하지 않음.) 세 리스트의 상호 배타성은 항상 보장한다.
- 기존 `strengths`/`gaps`/`suggestions`/`summary`/`matchingScore` 산출 로직은 변경하지 않는다(현재 `matched`/`gaps`는 산문용으로 별도 limit(3)을 쓰므로, 구조화 키워드 필드는 별도 산출 결과를 사용한다).

### ai-local (`GeminiMatchPreviewProvider`)

- 프롬프트 JSON 스키마에 키워드 배열 3개를 추가한다(예):

```
{
  "matchingScore": number 0~100,
  "summary": "...",
  "strengths": ["..."],
  "gaps": ["..."],
  "suggestions": ["..."],
  "matchedKeywords": ["JD 키워드 중 이력서에서 확인되는 항목"],
  "partialKeywords": ["동의어/유사 표현으로 부분 확인되는 항목"],
  "missingKeywords": ["이력서에서 확인되지 않는 항목"]
}
```

- 프롬프트 규칙에 "세 키워드 배열은 상호 배타적, 각 0~8개" 지침을 추가한다.
- 응답 파싱에서 세 배열을 `toStringList`로 읽는다.
- **키워드 필드 검증 정책(확정: 관대 처리)**: 키워드 배열은 관대하게 처리한다 — 누락/비배열이면 빈 리스트로 채우고 성공 응답을 유지한다. 기존 필수 필드(점수/summary/strengths/gaps/suggestions)의 검증·`GEMINI_API_RESPONSE_INVALID` 정책은 그대로 둔다. (키워드 필수 강제는 모델 변동성으로 실패율이 올라 채택하지 않음.)

## 실패 응답 계약 (변경 없음)

- 기존 검증·에러 코드(`EMPTY_RESUME`, `TEXT_TOO_SHORT`, `TEXT_TOO_LONG`, `EMPTY_JD`, `JD_TEXT_TOO_SHORT`, `JD_TEXT_TOO_LONG`, `INVALID_JD_URL`, `GEMINI_API_*`)를 그대로 사용한다. 새 에러 코드는 추가하지 않는다.
- 모든 실패는 기존과 동일하게 `ApiResponse` 에러 형태로 반환한다.

## 경계·보안 원칙

- 경계는 `Controller -> Service -> External API`를 유지한다. 키워드 분류는 서비스/프로바이더 계층 책임이다.
- 비밀 키 등 민감정보는 서버에서만 처리하며 프론트에 저장·노출하지 않는다(기존 원칙 유지).
