# 키워드 매칭 구조화 / 키워드 분석 옵션 해금 요구사항

JD 적합도 매칭(`POST /api/match/preview`) 결과에 **구조화된 키워드 브레이크다운**(매칭/부분/누락)을 더하고, 현재 "준비중"인 프론트 분석 옵션 `keyword`를 실기능으로 **해금**한다. 기존 매칭 호출 1회를 재사용하며, 새 엔드포인트는 추가하지 않는다. 모든 모드(`stub`/`fixture`/`ai-local`)가 동일한 키워드 필드를 반환한다.

## 배경 (현재 화면·코드)

- 백엔드 응답 `MatchPreviewResponse`(`backend/src/main/java/com/jdsnack/match/MatchPreviewResponse.java`)는 `matchingScore`, `summary`, `strengths`, `gaps`, `suggestions`만 노출한다. 키워드는 **비구조화**되어 산문(`strengths`/`gaps`) 안에 녹아 있다.
- `stub`/`fixture` 경로(`MatchPreviewService.buildPreview`)는 이미 내부적으로 JD·이력서 키워드를 추출하고 `matched`/`gaps` 키워드 목록을 만들지만(`extractKeywords`), 응답 필드로는 내보내지 않는다.
- `ai-local`(Gemini, `GeminiMatchPreviewProvider`)는 키워드를 구조화해 받지 않는다(프롬프트 스키마에 키워드 배열이 없음).
- 프론트 분석 옵션 `keyword`는 `enabled: false`("준비중", `frontend/src/App.tsx` 약 51~56행)이고, 결과 화면에는 자리만 있다(`submittedOptions.keyword` 분기에서 `ComingSoonPanel`, 약 770행).
- 매칭 호출은 `options.jdMatch`가 선택됐을 때만 발생한다(`App.tsx` `handleStartAnalysis` 약 441행: `submitFile` → `submitPreview`). `keyword`만 단독 선택 시 현재 흐름에서는 매칭 호출이 트리거되지 않는다(아래 `REQ-04`·열린 질문 참조).

## 용어 정의 (키워드 분류)

- **matched(매칭)**: JD 핵심 키워드가 이력서 본문에서 직접 확인되는 키워드.
- **partial(부분)**: JD 키워드가 정확히 일치하지는 않지만, 동의어·어간·표기 변형 등으로 이력서에서 근사하게 확인되는 키워드. 판정 강도는 모드별 능력에 따라 다르다(아래 `REQ-03`·열린 질문 참조).
- **missing(누락)**: JD 핵심 키워드가 이력서에서 matched·partial 어느 쪽으로도 확인되지 않는 키워드.
- 세 집합은 **상호 배타적**이며, 한 JD 키워드는 정확히 한 분류에만 속한다.

## `REQ-01` 응답에 키워드 브레이크다운 추가 (하위호환 확장)

- `MatchPreviewResponse`에 키워드 브레이크다운 필드를 **추가**한다(권장 명: `matchedKeywords`, `partialKeywords`, `missingKeywords`, 각각 문자열 리스트). 기존 필드(`matchingScore`/`summary`/`strengths`/`gaps`/`suggestions`)는 변경하지 않는다.
- 추가 필드는 항상 존재하며(누락 시 빈 리스트), 세 리스트는 상호 배타적이다.
- 키워드 항목 수에는 상한을 둔다(현행 `MAX_KEYWORDS=8` 기준선 재사용 또는 분류별 상한 명시 — `api-spec.md` 참조).

## `REQ-02` 프론트 `keyword` 옵션 해금 + 결과 패널

- `ANALYSIS_OPTIONS`의 `keyword` 항목을 `enabled: true`로 바꿔 선택 가능하게 한다("준비중" 태그 제거).
- `keyword` 옵션이 제출에 포함되면, 결과 화면의 `submittedOptions.keyword` 자리에 `ComingSoonPanel` 대신 **키워드 브레이크다운 패널**(매칭/부분/누락 섹션)을 표시한다.
- 키워드 결과는 매칭 응답(`MatchPreviewResult`)에서 가져온다. 프론트 타입(`frontend/src/types/diagnosis.ts` `MatchPreviewResult`)과 응답 매핑(`frontend/src/services/api.ts` `previewMatch`)에 새 필드를 더한다.

## `REQ-03` 모드 전체 동일 계약 (stub / fixture / ai-local)

- 세 모드 모두 `matchedKeywords`/`partialKeywords`/`missingKeywords`를 반환한다(필드 존재 보장).
- `stub`/`fixture`: 기존 `buildPreview`의 키워드 추출을 재사용해 matched/missing을 구성하고, partial은 모드 능력 범위 내에서 근사한다(정의는 `api-spec.md`에서 확정, 단순 토큰 매칭 한계는 열린 질문으로 표기).
- `ai-local`(Gemini): 프롬프트 JSON 스키마에 세 키워드 배열을 추가하고, 응답 파싱·검증에 반영한다. 모델이 비정상 응답(필드 누락 등)일 때의 처리는 기존 `GEMINI_API_RESPONSE_INVALID` 검증 정책과 일관되게 둔다(키워드 필드의 필수/관대 여부는 `api-spec.md`에서 확정).

## `REQ-04` 통합 검증 게이트와의 정합

- 직전 spec(`analysis-prevalidation-gate`)의 통합 검증 게이트를 따른다: `keyword` 옵션을 선택해도 이력서(파일 선택)·JD(최소/최대 길이)·분석 항목(1개 이상) 검증을 통과한 뒤에만 분석이 실행된다.
- `keyword`는 매칭 응답에 의존하므로, `keyword`가 선택되면 매칭 호출(`submitFile` → `submitPreview`)이 수행되도록 한다. `jdMatch` 미선택 + `keyword`만 선택 시의 점수/서술 표시 여부는 **열린 질문**으로 남긴다(아래 참조). 본 spec의 권장안은 "`keyword` 또는 `jdMatch` 중 하나라도 선택되면 매칭을 호출하되, JD 적합도 점수/강점·gap·제안 패널은 `jdMatch` 선택 시에만 표시"이다.

## 범위 밖

- 새 API 엔드포인트 추가. 키워드는 기존 `/api/match/preview` 응답 확장으로만 제공한다.
- 키워드 추출 알고리즘의 고도화(형태소 분석기 도입, 임베딩 기반 유사도 등). 본 spec은 기존 토큰 기반 추출 위에서 분류를 구조화할 뿐이다(고도화는 별도 spec).
- 검증 임계값(JD/이력서 50/10,000) 변경, `ApiResponse<T>` 래퍼·`ErrorCode` 체계 변경.
- ATS·문장 첨삭 등 다른 "준비중" 옵션 해금.
- JD 적합도 점수 계산식 변경.
