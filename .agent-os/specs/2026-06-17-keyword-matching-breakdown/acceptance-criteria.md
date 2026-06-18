# 키워드 매칭 구조화 / 키워드 분석 옵션 해금 수용 기준

## `AC-01` 응답 키워드 브레이크다운 필드 (하위호환)

- `POST /api/match/preview` 응답에 `matchedKeywords`, `partialKeywords`, `missingKeywords`(각 문자열 리스트)가 포함된다.
- 세 필드는 항상 존재한다(해당 분류가 없으면 빈 리스트). null이 아니다.
- 세 리스트는 상호 배타적이다(같은 키워드가 둘 이상 분류에 중복 등장하지 않는다).
- 기존 필드(`matchingScore`/`summary`/`strengths`/`gaps`/`suggestions`)의 형태·의미는 변하지 않는다.
- 분류별 항목 수가 상한(`api-spec.md`에 명시된 값)을 넘지 않는다.

## `AC-02` stub/fixture 모드 키워드 산출

- `stub`/`fixture` 모드에서 JD 핵심 키워드가 이력서에 존재하면 `matchedKeywords`에, 존재하지 않으면 `missingKeywords`에 분류된다.
- `partialKeywords`는 `api-spec.md`가 정의한 stub/fixture 판정 규칙대로 산출된다(규칙상 partial이 없을 수 있으며, 그 경우 빈 리스트).
- 동일 입력에 대해 결과가 결정적이다(같은 JD·이력서 → 같은 분류).

## `AC-03` ai-local(Gemini) 모드 키워드 산출

- `ai-local` 모드에서 Gemini 프롬프트 스키마에 키워드 배열이 포함되고, 응답에서 `matchedKeywords`/`partialKeywords`/`missingKeywords`로 파싱된다.
- Gemini 응답이 키워드 필드 처리 규칙(`api-spec.md`의 필수/관대 정책)을 위반하면, 기존 `GEMINI_API_RESPONSE_INVALID` 정책과 일관되게 처리된다(성공 응답에 빈 리스트를 채우거나 오류 반환 — `api-spec.md`에서 확정).
- 기존 Gemini 검증(점수 0~100, summary/strengths/gaps/suggestions 비어 있지 않음)은 그대로 유지된다.

## `AC-04` 프론트 keyword 옵션 해금

- 분석 옵션 목록에서 `키워드 분석` 항목이 선택 가능하고 "준비중" 태그가 표시되지 않는다.
- `keyword`를 선택해 제출하면 결과 화면에 키워드 브레이크다운 패널(매칭/부분/누락 섹션)이 표시되고, `ComingSoonPanel`이 표시되지 않는다.
- `keyword`를 선택하지 않으면 키워드 브레이크다운 패널이 표시되지 않는다.
- 키워드 패널은 매칭 응답(`MatchPreviewResult`)의 새 필드에서 값을 가져온다.

## `AC-05` keyword 결과의 매칭 호출 정합

- `keyword`가 선택되면 매칭 호출(`submitFile` → `submitPreview`)이 수행되어 키워드 데이터를 받는다.
- `jdMatch` 미선택 + `keyword` 단독 선택 시의 점수/서술 패널 표시 동작은 `ui-spec.md`가 확정한 동작(권장: 키워드 패널만 표시, JD 적합도 점수/강점·gap·제안 패널은 비표시)을 따른다.
- 키워드 분류가 비어 있는 경우(예: 매칭 0건)에도 패널은 빈 상태 문구로 깨지지 않고 표시된다.

## `AC-06` 통합 검증 게이트·기존 흐름 보존

- `keyword` 옵션 선택 시에도 직전 spec의 통합 검증 게이트를 통과한 뒤에만 분석이 실행된다(이력서 파일 선택 + JD 50~10,000자 + 분석 항목 1개 이상).
- `jdMatch` 기존 패널(점수/강점/gap/제안)·진단→매칭 순서·기존 에러 처리(키 누락·Gemini 실패 등)가 유지된다.
- 응답은 기존 `ApiResponse<T>` 래퍼·`ErrorCode` 체계를 그대로 따른다(새 에러 코드·새 엔드포인트 없음).
- 키워드 패널은 명확한 label/role과 좁은 폭 레이아웃 기준(접근성·반응형)을 따른다.
