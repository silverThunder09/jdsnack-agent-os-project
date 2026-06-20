# Work Start Checkpoint

## Target Spec
- 대상 spec: `.agent-os/specs/2026-06-18-sentence-editing/`

## Risk Level
- `Standard`
- 판단 이유: 신규 전용 엔드포인트·신규 백엔드 패키지·신규 프론트 호출/훅/패널이 함께 추가되지만, 요청 계약·검증·`ErrorCode`·`ApiResponse<T>` 래퍼는 매칭에서 그대로 재사용하고 새 에러 코드·임계값 변경은 없다. 매칭 프롬프트/파싱 패턴을 복제하므로 모드별(`stub`/`fixture`/`ai-local`) 회귀 확인이 필요하다.

## Change Scope
> [2026-06-19 개정] 아래는 최초 구현(#87 머지) 기준 기록이다. 머지 후 UI 결함 수정으로 **사이드바 `맞춤 첨삭` 잠금 메뉴 제거** + **옵션 라벨 `맞춤 첨삭`→`문장 첨삭`** 2건이 추가 범위로 들어왔다(아래 "바꾸지 않는 것"의 사이드바 항목은 더 이상 유효하지 않음). 상세는 `ui-spec.md`/`requirements.md` 개정 결정 참조.

- 이번 작업에서 바꾸는 것(추가): 백엔드 신규 패키지 `com.jdsnack.sentence`(`SentencePreviewController`/`SentencePreviewService`/`SentencePreviewRequest`/`SentencePreviewResponse`/`SentenceEdit`/`Stub`·`Fixture`·`GeminiSentencePreviewProvider`), 프론트 `frontend/src/types/diagnosis.ts`(`SentenceEdit`/`SentencePreviewResult`)·`frontend/src/services/api.ts`(`previewSentence`)·`frontend/src/hooks/useSentencePreview.ts`·`frontend/src/App.tsx`(sentence 옵션 해금·결과 패널·호출 트리거·`buildResultMarkdown`), 관련 백엔드/프론트 테스트.
- 이번 작업에서 바꾸지 않는 것: 매칭/키워드 엔드포인트·요청 스키마·`ApiResponse<T>` 래퍼·`ErrorCode`, 검증 임계값(50/10,000), 기존 JD 적합도·키워드 패널·셸, 사이드바 `맞춤 첨삭` 잠금 메뉴, 다른 `ComingSoonPanel`(ATS).

## Read Scope
- 반드시 읽을 문서/폴더: 본 spec의 `requirements.md`·`acceptance-criteria.md`·`test-scenarios.md`·`api-spec.md`·`ui-spec.md`·`traceability.md`, `AGENTS.md`, `.agent-os/standards/backend.md`·`frontend.md`·`api.md`·`testing-standards.md`, `.agent-os/operations/gemini-local-test-policy.md`.
- 필요할 때만 읽을 문서/폴더: `backend/src/main/java/com/jdsnack/match/*`(프롬프트·파싱·검증 패턴 복제 참고), `backend/src/test/java/com/jdsnack/match/*`(미러 테스트 참고), `frontend/src/hooks/useMatchPreview.ts`, `frontend/src/services/api.ts`(`previewMatch`).

## Do Not Read
- 기본 탐색 제외: `frontend/node_modules`, `frontend/dist`, `backend/build`, `backend/.gradle`, `.agent-os/archive`, `.git`.
- 예외적으로만 확인할 범위: archive된 이전 spec(맥락 필요 시).

## Test Plan
- 로컬 테스트: `cd frontend && npm run lint && npm test && npm run build && npm run test:e2e`, `cd backend && ./gradlew test`.
- 백엔드(미러): `GeminiSentencePreviewProviderTest`(프롬프트·파싱·관대 처리), `SentencePreviewControllerTest`(stub), `SentencePreviewFixtureModeControllerTest`(fixture), `SentencePreviewAiLocalModeControllerTest`(ai-local, HttpClient 스텁).
- 프론트: sentence 옵션 해금/패널 표시 단위 테스트(`App.test.tsx`), 빈 edits 상태, 독립 호출 e2e.
- 수동 검증: `fixture` 모드에서 문장 첨삭 패널 표시, `ai-local` 모드에서 Gemini edits 파싱(`gemini-local-test-policy.md`에 따라).
- CI 기대 항목: 프론트 lint/test/build/e2e, 백엔드 test, 문서 harness 인덱스 검증.

## PR Scope
- PR 주 목적: 문장 첨삭 신규 엔드포인트 + sentence 옵션 해금.
- 같은 PR에 포함할 항목: 백엔드 신규 패키지(3모드)·프론트 타입/서비스/훅/패널/호출 트리거·내보내기 마크다운, 관련 테스트.
- 별도 PR로 분리할 항목: 문서 PR(이 spec 추가·archive 이동·포인터 갱신), 사이드바 `맞춤 첨삭` 별도 화면(향후), ATS 등 다른 "준비중" 옵션 해금.
