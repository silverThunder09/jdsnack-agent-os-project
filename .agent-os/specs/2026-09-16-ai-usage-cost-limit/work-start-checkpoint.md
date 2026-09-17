# Work Start Checkpoint

## Target Spec

- 대상 spec: `2026-09-16-ai-usage-cost-limit`
- 대상 티켓: T2 프론트 quota 오류 안내

## Risk Level

- `Standard`
- 기존 DB·외부 provider 구현은 변경하지 않고, 이미 머지된 API 계약을 프론트에서 해석한다.

## Change Scope

- `AI_QUOTA_EXCEEDED` error metadata 타입과 API 예외 보존
- 분석 이력 JSON/file 요청의 `Idempotency-Key` 전달
- quota 초과 시 remaining/limit/resetAt 안내와 회귀 테스트
- T1 완료·T2 진행 상태를 plan에 기록

## Read Scope

- 활성 spec의 requirements, acceptance-criteria, test-scenarios, api-spec, ui-spec, traceability
- frontend API 서비스, 분석 진행 상태 컴포넌트·테스트
- frontend/API/testing standards와 PR rules

## Do Not Read

- backend 구현·migration은 계약 확인 외에 변경하지 않는다.
- archive, node_modules, dist, build, .gradle은 탐색하지 않는다.

## Test Plan

- `cd frontend && npm run lint`
- `cd frontend && npm test -- --run`
- `cd frontend && npm run build`
- `python scripts/check-ai-readiness.py`
- GitHub PR의 frontend CI와 Docs Harness 확인

## PR Scope

- PR 주 목적: #205에서 누락된 동일 quota spec의 프론트 계약 보완
- 같은 PR에 포함: frontend 구현·테스트와 해당 active spec plan/traceability/test-scenarios 갱신
- 별도 PR로 분리: backend, DB migration, CI/CD, 다음 제품 spec
- `docker` 실행 파일이 없어 Compose/health 검증은 로컬에서 실행하지 못했다.
