# 문장 첨삭(맞춤 첨삭, 문장 단위) 테스트 시나리오

## `TC-01` stub 모드: edits 반환

- 대응 AC: `AC-01`, `AC-02`
- 절차: `stub` 모드에서 정상 입력(이력서·JD 50자 이상)으로 `POST /api/sentence/preview` 호출(`SentencePreviewControllerTest`, MockMvc).
- 기대 결과: 응답에 `edits` 배열이 존재하고 각 항목이 `original`/`improved`/`reason`을 가진다. 항목 수가 상한(8)을 넘지 않으며, 동일 입력에 대해 결정적이다. `ApiResponse<SentencePreviewResponse>` 형태로 감싸진다.

## `TC-02` fixture 모드: edits 필드 존재

- 대응 AC: `AC-01`, `AC-02`
- 절차: `fixture` 모드에서 `POST /api/sentence/preview` 호출(`SentencePreviewFixtureModeControllerTest`).
- 기대 결과: `edits`가 항상 존재하고 null이 아니며(없으면 빈 리스트), 동일 입력에 대해 결정적 결과를 반환한다. 외부 호출이 발생하지 않는다.

## `TC-03` ai-local 모드: Gemini edits 파싱

- 대응 AC: `AC-03`
- 절차: `ai-local` 모드에서 주입된 HttpClient 스텁으로 `{"edits":[{"original","improved","reason"}]}` JSON을 반환하게 하고 `POST /api/sentence/preview` 호출(`SentencePreviewAiLocalModeControllerTest`). 프롬프트·파싱 단위 검증은 `GeminiSentencePreviewProviderTest`.
- 기대 결과: 응답의 `edits`가 Gemini JSON에서 파싱되어 각 항목의 `original`/`improved`/`reason`이 채워진다. `stripJsonFence`로 코드펜스가 제거된 JSON도 파싱된다.

## `TC-04` ai-local 모드: edits 누락/비배열 관대 처리

- 대응 AC: `AC-03`
- 절차: Gemini 응답에서 `edits`가 누락되거나 배열이 아닌 경우를 스텁으로 재현해 호출.
- 기대 결과: `api-spec.md` 확정 정책대로 빈 리스트로 채우고 성공(`success: true`) 응답을 반환한다. 응답 본문이 비-JSON이거나 호출이 실패한 경우에는 기존 `GEMINI_API_RESPONSE_INVALID`/`GEMINI_API_REQUEST_FAILED`로 처리됨을 함께 확인한다.

## `TC-05` 검증·에러 정책 재사용

- 대응 AC: `AC-04`
- 절차: 짧은 JD(50자 미만)·긴 이력서(10,000자 초과)·잘못된 `jdUrl`·빈 이력서 등으로 `POST /api/sentence/preview` 호출. `ai-local` 모드에서 API 키 미설정 케이스도 호출.
- 기대 결과: 각각 `JD_TEXT_TOO_SHORT`/`TEXT_TOO_LONG`/`INVALID_JD_URL`/`EMPTY_RESUME` 등 기존 `ErrorCode`로 매칭과 동일하게 반환된다. 키 미설정 시 `GEMINI_API_KEY_MISSING`. 새 에러 코드가 등장하지 않는다.

## `TC-06` 프론트: sentence 옵션 해금 + 패널 표시

- 대응 AC: `AC-05`
- 절차: 분석 옵션에서 `문장 첨삭`이 선택 가능함을 확인하고 선택해 제출(`App.test.tsx` 또는 playwright). `previewSentence` 응답은 `edits`를 포함하도록 모킹/fixture.
- 기대 결과: `문장 첨삭`에 "준비중" 태그가 없고 선택된다. 결과 화면에 문장 첨삭 패널(문장별 Before→After 카드 + 사유)이 표시되고 `ComingSoonPanel`이 표시되지 않는다. 미선택 시 패널이 없다.
- **[개정 2026-06-19] 구현 시 단언 갱신 필수**: 이미 머지된 프론트 테스트가 옵션 라벨을 `맞춤 첨삭`으로 단언하고 있다. Codex는 라벨 변경에 맞춰 아래 단언을 `문장 첨삭`으로 수정한다.
  - `frontend/src/App.test.tsx` 약 109행(테스트명 `...맞춤 첨삭은 선택 가능하고...`), 114행·145행의 `getByRole('checkbox', { name: /맞춤 첨삭/ })`, 156행·176행 테스트명 → `문장 첨삭`.
  - `frontend/e2e/upload-and-jd-preview.spec.ts` 약 154행 `getByRole('checkbox', { name: /맞춤 첨삭/ }).uncheck()`, 164행 테스트명 → `문장 첨삭`.
  - 결과 패널 heading 단언(`name: '문장 첨삭'`, App.test.tsx 약 168행·e2e 약 142/175행)은 이미 `문장 첨삭`이므로 그대로 둔다.

## `TC-07` 프론트: 빈 edits 상태 처리

- 대응 AC: `AC-06`
- 절차: `previewSentence` 응답의 `edits`가 빈 배열인 경우를 모킹.
- 기대 결과: 문장 첨삭 패널이 빈 상태 문구(예: "첨삭할 문장이 없습니다.")로 정상 렌더되고 레이아웃이 깨지지 않는다.

## `TC-08` 프론트: 독립 호출·결과 표시

- 대응 AC: `AC-06`
- 절차: `sentence`만 선택해 제출한 경우와 `jdMatch`+`sentence`를 함께 선택한 경우를 각각 검증(`useSentencePreview` 훅 단위 또는 e2e).
- 기대 결과: `sentence` 선택 시 `previewSentence` 호출이 매칭과 독립적으로 수행되어 첨삭 패널이 채워진다. 함께 선택 시 두 호출이 각각 수행되고 두 패널이 함께 표시된다.

## `TC-09` 통합 검증 게이트·기존 흐름·게이트 종합

- 대응 AC: `AC-07`
- 절차: `sentence` 선택 + 짧은 JD(50자 미만)로 시작 시도 → 게이트가 차단함을 확인. 이어 정상 입력으로 제출해 진단→분석 실행과 문장 첨삭 패널·내보내기 마크다운(문장 첨삭 섹션 포함)을 확인한다. `cd frontend && npm run lint`, `npm test`, `npm run build`, `npm run test:e2e`, `cd backend && ./gradlew test` 실행.
- 기대 결과: 게이트가 짧은 JD를 막고(직전 spec 동작 유지), 정상 입력에서 문장 첨삭 패널이 표시되며 내보내기 마크다운에 문장 첨삭 섹션(빈 `edits`에서도 안전)이 포함된다. lint·단위·빌드·e2e·백엔드 테스트가 통과한다.
- **[개정 2026-06-19] 사이드바 잠금 메뉴 단언 추가**: 사이드바 잠금 메뉴 목록에 `맞춤 첨삭`이 없음을 확인한다(예: `queryByRole('button', { name: /맞춤 첨삭/ })`가 사이드바에서 null, 또는 e2e에서 잠금 내비 항목에 `맞춤 첨삭` 미존재). `AppShell` 렌더 단위 테스트 또는 e2e 중 적합한 곳에 단언을 추가/갱신한다. 다른 잠금 항목(`분석 내역`/`이력서 관리`/`템플릿`/`키워드 사전`/`요금제`)은 여전히 존재함을 함께 확인한다.
