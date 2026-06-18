# 키워드 매칭 구조화 / 키워드 분석 옵션 해금 테스트 시나리오

## `TC-01` stub 모드: 키워드 브레이크다운 반환

- 대응 AC: `AC-01`, `AC-02`
- 절차: `stub` 모드에서 JD 일부 키워드가 이력서에 존재하고 일부는 누락되도록 입력해 `POST /api/match/preview` 호출(`MatchPreviewControllerTest` 확장, MockMvc).
- 기대 결과: 응답에 `matchedKeywords`/`partialKeywords`/`missingKeywords`가 존재하고, 존재하는 JD 키워드는 matched, 없는 키워드는 missing으로 분류된다. 세 리스트는 상호 배타적이며 항목 수 상한을 넘지 않는다. 기존 필드(`matchingScore` 등)는 그대로 반환된다.

## `TC-02` fixture 모드: 키워드 필드 존재

- 대응 AC: `AC-01`, `AC-02`
- 절차: `fixture` 모드에서 `POST /api/match/preview` 호출(`MatchPreviewFixtureModeControllerTest` 확장).
- 기대 결과: 세 키워드 필드가 항상 존재하고 null이 아니며(없으면 빈 리스트), 동일 입력에 대해 결정적 결과를 반환한다.

## `TC-03` ai-local 모드: Gemini 키워드 파싱

- 대응 AC: `AC-03`
- 절차: `ai-local` 모드에서 Gemini 응답을 스텁(주입된 HttpClient)으로 키워드 배열을 포함한 JSON을 반환하게 하고 `POST /api/match/preview` 호출(`MatchPreviewAiLocalModeControllerTest` 확장).
- 기대 결과: 응답의 `matchedKeywords`/`partialKeywords`/`missingKeywords`가 Gemini JSON에서 파싱된다. 기존 점수/summary/strengths/gaps/suggestions 검증도 통과한다.

## `TC-04` ai-local 모드: 키워드 필드 누락 응답 처리

- 대응 AC: `AC-03`
- 절차: Gemini 응답에서 키워드 배열이 누락/비배열인 경우를 스텁으로 재현해 호출.
- 기대 결과: `api-spec.md`가 확정한 정책대로 처리된다(권장: 키워드는 관대 처리해 빈 리스트로 채우고 성공 반환, 단 기존 필수 필드 누락 시에는 기존대로 `GEMINI_API_RESPONSE_INVALID`). 확정 정책과 일치함을 검증한다.

## `TC-05` 프론트: keyword 옵션 해금 + 패널 표시

- 대응 AC: `AC-04`
- 절차: 분석 옵션에서 `키워드 분석`을 선택 가능함을 확인하고 선택해 제출(프론트 단위 테스트 또는 playwright). 매칭 응답은 키워드 필드를 포함하도록 모킹/fixture.
- 기대 결과: `키워드 분석`에 "준비중" 태그가 없고 선택된다. 결과 화면에 키워드 브레이크다운 패널(매칭/부분/누락)이 표시되고 `ComingSoonPanel`이 표시되지 않는다. 미선택 시 패널이 없다.

## `TC-06` 프론트: keyword 단독 선택 시 동작

- 대응 AC: `AC-05`
- 절차: `jdMatch`는 끄고 `keyword`만 선택해 정상 입력으로 제출.
- 기대 결과: 매칭 호출이 수행되어 키워드 패널이 채워진다. `ui-spec.md` 확정 동작에 따라 JD 적합도 점수/강점·gap·제안 패널은 표시되지 않고(권장안) 키워드 패널만 표시된다.

## `TC-07` 프론트: 빈 분류 상태 처리

- 대응 AC: `AC-05`
- 절차: 매칭 응답의 키워드 분류가 일부 또는 전부 비어 있는 경우를 모킹.
- 기대 결과: 키워드 패널이 빈 상태 문구로 정상 렌더되고 레이아웃이 깨지지 않는다.

## `TC-08` 통합 검증 게이트·기존 흐름·게이트 종합

- 대응 AC: `AC-06`
- 절차: `keyword` 선택 + 짧은 JD(50자 미만)로 시작 시도 → 게이트가 차단함을 확인. 이어 정상 입력으로 `jdMatch`+`keyword` 동시 선택해 진단→매칭 실행과 두 패널 표시를 확인한다. `cd frontend && npm run lint`, `npm test`, `npm run build`, `npm run test:e2e`, `cd backend && ./gradlew test` 실행.
- 기대 결과: 게이트가 짧은 JD를 막고(직전 spec 동작 유지), 정상 입력에서 진단→매칭 순서·기존 JD 적합도 패널·키워드 패널이 함께 표시된다. lint·단위·빌드·e2e·백엔드 테스트가 통과한다.
