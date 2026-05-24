# JDSnack 에이전트 안내 지도

JDSnack은 개발자 이력서와 JD를 AI로 분석하는 웹 서비스입니다. 현재 활성 기획은 커스텀 에이전트 TOML 전환이며, 과거 MVP 문서는 archive에 보관합니다.

이 파일은 긴 설명서가 아니라, 작업을 시작할 때 보는 짧은 지도입니다.

## 먼저 읽을 문서

1. 제품 목적: `.agent-os/product/mission.md`
2. 기술 방향: `.agent-os/product/tech-stack.md`
3. 하네스 규칙: `.agent-os/standards/codex-harness.md`
4. 서브 에이전트 규칙: `.agent-os/standards/sub-agent-operations.md`
5. 현재 활성 기능: `.agent-os/specs/2026-05-24-custom-agent-toml/`

## 기준 문서 위치

- 제품 방향: `.agent-os/product/`
- 활성 기능 명세: `.agent-os/specs/`
- 보관 기능 명세: `.agent-os/archive/specs/`
- 전역 표준: `.agent-os/standards/`
- 운영 규칙: `.agent-os/operations/`
- 커스텀 에이전트: `.codex/agents/`
- 상세 API 문서: `docs/api/`
- 상세 ERD 문서: `docs/erd/`
- 상세 아키텍처 문서: `docs/architecture/`
- 백엔드 코드: `backend/`
- 프론트엔드 코드: `frontend/`

## 작업 순서

1. `requirements.md`에서 요구사항을 확인합니다.
2. `acceptance-criteria.md`에서 완료 기준을 확인합니다.
3. `test-scenarios.md`에서 검증 시나리오를 확인합니다.
4. `api-spec.md`와 `ui-spec.md`에서 계약을 확인합니다.
5. 구현 후 `traceability.md`와 테스트 결과를 맞춥니다.

## 강제 규칙

- 문서 없는 API/UI 계약 변경은 하지 않습니다.
- 대응 테스트 시나리오 없는 수용 기준을 추가하지 않습니다.
- 에이전트 역할 변경 시 `.codex/agents/*.toml`과 `.agent-os/standards/sub-agent-operations.md`를 함께 최신화합니다.
- 사용자가 브라우저에서 비밀 키를 넣거나 프론트에 저장하는 흐름은 만들지 않습니다.
- 백엔드는 `Controller -> Service -> Repository/External API` 경계를 지킵니다.
- 프론트는 컴포넌트에서 직접 API 호출을 하지 않고 서비스 계층을 둡니다.
- 작업 종료 시 `.agent-os/operations/agent-handoff-template.md` 형식으로 handoff를 남깁니다.
- 커밋/PR/머지 규칙은 `.agent-os/standards/git-workflow.md`, `.agent-os/operations/pr-rules.md`, `.agent-os/operations/merge-rules.md`를 따릅니다.
