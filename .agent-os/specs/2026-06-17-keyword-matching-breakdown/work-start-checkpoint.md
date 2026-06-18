# Work Start Checkpoint

## Target Spec
- 대상 spec: `.agent-os/specs/2026-06-17-keyword-matching-breakdown/`

## Risk Level
- `Standard`
- 판단 이유: 응답 스키마 확장(하위호환 추가)·프론트 옵션 해금·매칭 트리거 조건 변경이 함께 걸리지만, 새 엔드포인트·새 ErrorCode·임계값 변경은 없고 기존 매칭 호출과 추출 로직을 재사용한다. `ai-local` 프롬프트 변경이 있어 모드별 회귀 확인이 필요하다.

## Change Scope
- 이번 작업에서 바꾸는 것: `MatchPreviewResponse`(키워드 필드 추가), `MatchPreviewService.buildPreview`(구조화 키워드 산출), `GeminiMatchPreviewProvider`(프롬프트·파싱), `frontend/src/App.tsx`(keyword 옵션 해금·결과 패널·매칭 트리거 조건), `frontend/src/types/diagnosis.ts`·`frontend/src/services/api.ts`(새 필드 매핑), 관련 백엔드/프론트 테스트.
- 이번 작업에서 바꾸지 않는 것: 매칭 엔드포인트·요청 스키마·`ApiResponse<T>` 래퍼·`ErrorCode`, 검증 임계값(50/10,000), JD 적합도 점수 계산식, 기존 JD 적합도 패널·셸·다른 ComingSoonPanel.

## Read Scope
- 반드시 읽을 문서/폴더: 본 spec의 `requirements.md`·`acceptance-criteria.md`·`test-scenarios.md`·`api-spec.md`·`ui-spec.md`·`traceability.md`, `AGENTS.md`, `.agent-os/standards/backend.md`·`frontend.md`·`api.md`·`testing-standards.md`, `.agent-os/operations/gemini-local-test-policy.md`.
- 필요할 때만 읽을 문서/폴더: `backend/src/main/java/com/jdsnack/match/*`, `backend/src/test/java/com/jdsnack/match/*`, `frontend/src/hooks/useMatchPreview.ts`.

## Do Not Read
- 기본 탐색 제외: `frontend/node_modules`, `frontend/dist`, `backend/build`, `backend/.gradle`, `.agent-os/archive`, `.git`.
- 예외적으로만 확인할 범위: archive된 이전 spec(맥락 필요 시), 직전 active spec(통합 검증 게이트, 정합 확인 시).

## Test Plan
- 로컬 테스트: `cd frontend && npm run lint && npm test && npm run build && npm run test:e2e`, `cd backend && ./gradlew test`.
- 백엔드: `MatchPreviewControllerTest`(stub)·`MatchPreviewFixtureModeControllerTest`(fixture)·`MatchPreviewAiLocalModeControllerTest`(ai-local)에 키워드 필드 검증 추가.
- 프론트: keyword 옵션 해금/패널 표시 단위 테스트, keyword 단독 선택 동작 e2e.
- 수동 검증: `fixture` 모드에서 키워드 패널 표시, `ai-local` 모드에서 Gemini 키워드 파싱(정책에 따라).
- CI 기대 항목: 프론트 lint/test/build/e2e, 백엔드 test, 문서 harness 인덱스 검증.

## PR Scope
- PR 주 목적: 키워드 매칭 구조화 + keyword 옵션 해금.
- 같은 PR에 포함할 항목: 응답 확장(백엔드 3모드), 프론트 옵션 해금·패널·매칭 트리거, 관련 테스트.
- 별도 PR로 분리할 항목: 문서 PR(이 spec 추가·archive 이동·포인터 갱신), 키워드 추출 알고리즘 고도화(필요 시), 다른 "준비중" 옵션 해금.
