# Work Start Checkpoint

## Target Spec
- 대상 spec: `.agent-os/specs/2026-06-17-analysis-prevalidation-gate/`

## Risk Level
- `Standard`
- 판단 이유: 프론트 게이팅 로직 변경(호출 차단)과 백엔드 재검증 보장이 함께 걸리지만, 신규 API·스키마·임계값 변경은 없고 기존 검증 함수를 재사용한다.

## Change Scope
- 이번 작업에서 바꾸는 것: `frontend/src/App.tsx`의 분석 시작 게이트(통합 검증으로 대체, JD 길이 검증을 게이트로 이동), 관련 단위·e2e 테스트, 백엔드 방어적 재검증 테스트.
- 이번 작업에서 바꾸지 않는 것: 검증 임계값(50/10,000), API 엔드포인트·응답 스키마·ErrorCode, 결과 화면·셸·결과 표시 컴포넌트.

## Read Scope
- 반드시 읽을 문서/폴더: 본 spec의 `requirements.md`·`acceptance-criteria.md`·`test-scenarios.md`·`api-spec.md`·`ui-spec.md`·`traceability.md`, `AGENTS.md`, `.agent-os/standards/frontend.md`·`backend.md`·`testing-standards.md`.
- 필요할 때만 읽을 문서/폴더: `frontend/src/hooks/useMatchPreview.ts`·`useDiagnose.ts`, `backend/src/main/java/com/jdsnack/match`·`diagnose`.

## Do Not Read
- 기본 탐색 제외: `frontend/node_modules`, `frontend/dist`, `backend/build`, `backend/.gradle`, `.agent-os/archive`, `.git`.
- 예외적으로만 확인할 범위: archive된 이전 spec(맥락 필요 시).

## Test Plan
- 로컬 테스트: `cd frontend && npm run lint && npm test && npm run build && npm run test:e2e`, `cd backend && ./gradlew test`.
- 수동 검증: 짧은 JD 상태에서 네트워크 탭에 `/api/diagnose/file` 호출이 없는지, `fixture` 모드에서 정상 흐름 확인.
- CI 기대 항목: 프론트 lint/test/build/e2e, 백엔드 test, 문서 harness 인덱스 검증.

## PR Scope
- PR 주 목적: 분석 실행 전 통합 검증 게이트(프론트 게이팅 + 백엔드 재검증 보장).
- 같은 PR에 포함할 항목: 게이트 구현, 관련 테스트.
- 별도 PR로 분리할 항목: 문서 PR(이 spec 추가·archive 이동·포인터 갱신), 임계값 조정(필요 시).
