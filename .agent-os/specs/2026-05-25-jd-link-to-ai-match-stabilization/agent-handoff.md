# Agent Handoff

## Feature

- 기능명: JD 링크 to AI 매칭 안정화

## Current Phase

- DevOps

## Source Documents

- `test-scenarios.md`
- `traceability.md`
- `plan.md`
- `.agent-os/operations/container-workflow.md`
- `.agent-os/operations/deploy-runbook.md`

## Changed Files

- `compose.local.yaml`
- `compose.prod.yaml`
- `README.md`
- `.github/workflows/container.yml`
- `.agent-os/operations/container-workflow.md`
- `.agent-os/operations/deploy-runbook.md`
- `.agent-os/operations/browser-smoke-checks.md`
- `.agent-os/operations/gemini-local-test-policy.md`
- `.agent-os/specs/2026-05-25-jd-link-to-ai-match-stabilization/plan.md`
- `.agent-os/specs/2026-05-25-jd-link-to-ai-match-stabilization/test-scenarios.md`
- `.agent-os/specs/2026-05-25-jd-link-to-ai-match-stabilization/traceability.md`

## Decisions Made

- 로컬 개발/검증은 `compose.local.yaml`에서 `build:`로 소스 이미지를 빌드한다.
- 배포/운영 실행은 `compose.prod.yaml`에서 `image:`로 GHCR 이미지를 pull한다.
- Docker image 경로는 소문자 registry 이름인 `ghcr.io/silverthunder09/...`를 사용한다.
- `main` push 후 backend/frontend 이미지를 `latest`와 `<git-sha>` 태그로 GHCR에 push한다.
- `docker compose config`는 secret을 출력할 수 있으므로 `--no-env-resolution`을 기본 검증 옵션으로 둔다.

## Change Requests

- `QA Reviewer`: `compose.local.yaml`과 `compose.prod.yaml` config 검증을 확인한다.
- `DevOps Steward`: main push 후 GHCR publish와 prod compose pull 동작을 GitHub Actions에서 확인한다.
- `Release Captain`: PR 본문에 로컬 build compose와 배포 pull compose 분리 이유를 명시한다.

## Open Questions

- 없음

## Risks

- GHCR package 권한이나 owner 대소문자 문제로 image push/pull이 실패할 수 있다.
- `docker compose config`를 기본 옵션으로 실행하면 `.env` secret이 출력될 수 있다.
- 실제 배포 플랫폼은 아직 확정하지 않았으므로 이번 변경은 image pull 가능한 compose 기준까지만 보장한다.

## Next Agent

- `QA Reviewer`
