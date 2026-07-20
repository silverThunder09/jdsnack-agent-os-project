# ATS 점수·포맷 진단 API 계약

## 변경 요약

문장 첨삭(`POST /api/sentence/preview`)과 동일한 방식으로 **신규 전용 엔드포인트 `POST /api/ats/preview`**를 추가한다. ATS 진단은 LLM 부하가 크고 매칭·문장과 독립적으로 단독 호출되어야 하므로 매칭 응답에 얹지 않고 분리한다. 요청 형태·입력 검증·`ErrorCode` 체계·`ApiResponse<T>` 래퍼를 재사용하며 **새 `ErrorCode`를 추가하지 않는다**. 계약 원칙 정본은 [api 표준](../../standards/api.md)이고, 분리형 preview 엔드포인트 선례는 [문장 첨삭 api-spec](../../archive/specs/2026-06-18-sentence-editing/api-spec.md), 응답 확장·관대 처리 선례는 [키워드 매칭 api-spec](../../archive/specs/2026-06-17-keyword-matching-breakdown/api-spec.md)이다.

## 공통

- 이 엔드포인트는 [Service MVP](../../archive/specs/2026-07-18-service-mvp) 인증 경계상 보호 API로 취급한다(기존 `/api/match/**`·`/api/sentence/**`와 동일). 세션 없는 요청은 controller 진입 전 `401 AUTHENTICATION_REQUIRED`로 종료한다.
- 브라우저 프론트 서비스 계층은 보호 API 요청에 `credentials: 'include'`를 사용하고 provider token·비밀 키를 저장·전송하지 않는다.
- 성공 응답은 기존 `ApiResponse<T>`(`success`/`data`/`error`) 래퍼를 사용한다.
- Entity는 응답으로 직접 노출하지 않고 전용 response DTO(`AtsPreviewResponse`)로 반환한다.

## 신규 엔드포인트

- `POST /api/ats/preview` — 이력서 ATS 통과 가능성 미리보기

### 요청 본문 (`AtsPreviewRequest`)

매칭·문장 요청과 동일한 형태다.

```
{
  "resumeSource": { "type": "TEXT" | "FILE", "value": "..." },
  "jdText": "...",
  "jdUrl": "..."   // 선택
}
```

- 매칭·문장과 동일한 검증을 재사용한다: 이력서/JD 길이 50~10,000자, `jdUrl` 존재 시 URL 검증. 검증·헬퍼는 동일 정책을 적용하며(중복 구현이 아니라 재사용) 재사용 방식은 구현 시 Codex가 결정한다.

### 응답 스키마 (`AtsPreviewResponse`)

```
{
  "atsScore": 0~100,                    // 종합 ATS 통과 가능성 점수 (정수)
  "summary": "...",                     // 진단 요약 (한국어)
  "parsingWarnings": ["..."],           // 파싱 안전성 경고 (표·이미지·비표준 섹션 등)
  "presentSections": ["..."],           // 감지된 표준 섹션
  "missingSections": ["..."],           // 누락된 표준 섹션
  "sectionOrderWarnings": ["..."],      // 섹션 순서 관련 경고
  "jdKeywordsCovered": ["..."],         // JD 키워드 중 이력서에서 기계적으로 발견됨
  "jdKeywordsMissing": ["..."]          // JD 키워드 중 이력서에서 발견되지 않음
}
```

- 모든 목록 필드는 항상 직렬화된다. 값이 없으면 빈 배열(`[]`)이며 null이 아니다.
- `jdKeywordsCovered`와 `jdKeywordsMissing`는 상호 배타적이다(한 키워드는 정확히 한 분류).
- `atsScore`는 0~100 정수, `summary`는 비어 있지 않은 문자열이다.
- 응답은 `ApiResponse<AtsPreviewResponse>` 형태로 감싼다.

### 필드별 진단 정의 (티켓 경계)

| 필드 | 진단 관점 | 도입 티켓 |
|---|---|---|
| `parsingWarnings` | 파싱 안전성(표·이미지 placeholder·비표준 섹션·다단 흔적) | T1 |
| `presentSections`/`missingSections`/`sectionOrderWarnings` | 구조 진단(표준 섹션 유무·순서) | T2 |
| `jdKeywordsCovered`/`jdKeywordsMissing` | JD 대비 키워드 최적화 | T3 |
| `atsScore`/`summary` | 위 진단 종합 (T1 파싱 안전성 기준선으로 도입, T2·T3에서 종합으로 확장) | T1→T2→T3 |

- T2·T3에서 응답 필드를 추가할 때는 **하위호환 추가만** 한다(기존 필드·형태 불변, 빈 배열 보장). `atsScore` 산출식은 진단 차원이 추가되며 종합으로 확장되지만 필드 형태·범위(0~100)는 유지한다.

## 항목 수 상한

- 각 목록 필드의 표시 상한 기준선은 매칭의 `MAX_KEYWORDS=8`과 동일 감각으로 둔다. 최종 상한 값은 구현 시 현행 상수 재사용으로 고정한다.

## 모드별 산출 규칙

모드 분기는 매칭·문장과 동일하게 서비스(`AtsPreviewService`)가 담당한다(`DiagnosisMode`의 `STUB`/`FIXTURE`/`AI_LOCAL` 분기). `stub`/`fixture`는 외부 호출 없이 결정적 결과를, `ai-local`만 Gemini로 분기한다.

### stub / fixture (`AtsPreviewService` / fixture provider)

- 외부 호출 없이 결정적 결과를 반환한다(같은 이력서·JD → 같은 응답).
- 파싱 안전성: 텍스트 내 표 구분자·이미지 placeholder·비표준 섹션 제목 등 결정적 신호를 규칙 기반으로 감지한다.
- 구조 진단: 표준 섹션 사전(예: 경력·학력·기술/스킬·프로젝트)과 대조해 present/missing/order를 산출한다.
- 키워드 최적화: 기존 `extractKeywords`류 토큰 추출을 재사용해 JD 키워드 ∩/− 이력서 키워드로 covered/missing을 산출한다(형태소·임베딩 고도화 없음, 상호 배타 보장).
- `atsScore`: 위 진단에서 결정적으로 계산한다. 모든 필드의 빈 배열 보장·null 아님 계약을 만족한다.

### ai-local (`GeminiAtsPreviewProvider`)

- 프롬프트는 매칭 `GeminiMatchPreviewProvider.prompt()` / 문장 `GeminiSentencePreviewProvider` 구조를 참고하되 출력 스키마를 `AtsPreviewResponse` 필드에 맞춘다(JSON-only·한국어, 마크다운 래핑 금지). 응답 파싱은 기존 `stripJsonFence` 계열 헬퍼를 재사용한다.
- 프롬프트 규칙에 "표·이미지·비표준 섹션 등 파싱 위험 요소 감지, 표준 섹션 유무·순서 진단, JD 키워드 covered/missing 상호 배타, 각 목록 0~8개, `atsScore` 0~100" 지침을 둔다.
- **진단 필드 검증 정책(관대 처리)**: 목록 필드가 누락/비배열이면 빈 리스트로, `atsScore` 누락/범위 밖이면 안전 기본값으로 채우고 성공 응답을 유지한다. 응답 본문이 JSON으로 파싱 불가하거나 Gemini 호출이 실패한 경우에만 기존 `GEMINI_API_RESPONSE_INVALID`/`GEMINI_API_REQUEST_FAILED`/`GEMINI_API_KEY_MISSING` 정책을 따른다.

## 실패 응답 계약 (변경 없음)

- 기존 검증·에러 코드(`EMPTY_RESUME`, `TEXT_TOO_SHORT`, `TEXT_TOO_LONG`, `EMPTY_JD`, `JD_TEXT_TOO_SHORT`, `JD_TEXT_TOO_LONG`, `INVALID_JD_URL`, `GEMINI_API_KEY_MISSING`, `GEMINI_API_REQUEST_FAILED`, `GEMINI_API_RESPONSE_INVALID`)를 그대로 사용한다. **새 에러 코드는 추가하지 않는다.**
- 모든 실패는 매칭·문장과 동일하게 `ApiResponse` 에러 형태로 반환한다.

## 경계·보안 원칙

- 경계는 `Controller -> Service -> External API`를 유지한다. ATS 진단은 신규 패키지 `com.jdsnack.ats`의 서비스/프로바이더 계층 책임이다. 상세 계층 규칙은 [coding-standards](../../standards/coding-standards.md)를 따른다.
- 비밀 키 등 민감정보는 서버에서만 처리하며 프론트에 저장·노출하지 않는다.
