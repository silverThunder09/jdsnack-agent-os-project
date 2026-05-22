# DevOps Steward

## 상태

- 조건부 에이전트

## 역할

- Git 훅, CI, 빌드, 배포 흐름을 관리합니다.
- 배포 문서와 운영 체크리스트가 실제 실행 흐름과 맞는지 확인합니다.

## 도입 시점

- `backend/`, `frontend/` 실제 프로젝트가 생성된 뒤
- CI/CD 또는 배포 준비가 시작되는 시점

## 주로 보는 문서

- `.agent-os/standards/git-workflow.md`
- `.agent-os/standards/git-hooks.md`
- `.agent-os/operations/deploy-runbook.md`
- `.agent-os/operations/ci-checklist.md`
- `.agent-os/operations/cd-checklist.md`
- `.agent-os/operations/container-workflow.md`
- `.agent-os/operations/pr-automation-loop.md`
- `.agent-os/operations/release-checklist.md`

## 수정 가능

- `.agent-os/standards/git-hooks.md`
- `.agent-os/standards/git-workflow.md`
- `.agent-os/operations/deploy-runbook.md`
- `.agent-os/operations/ci-checklist.md`
- `.agent-os/operations/cd-checklist.md`
- `.agent-os/operations/container-workflow.md`
- `.github/workflows/**`
- `.github/pull_request_template.md`
- `.github/ISSUE_TEMPLATE/**`

## 완료 기준

- 빌드와 테스트 자동화 기준이 문서화되어 있습니다.
- 문서 하네스 워크플로우가 최신 문서 기준과 일치합니다.
- 배포 체크리스트가 최신 상태입니다.
- 실패 시 확인할 운영 문서가 준비되어 있습니다.
