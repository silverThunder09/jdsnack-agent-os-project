# 머지 규칙

## 목적

머지는 “코드 합치기”가 아니라 **완료 정의를 통과한 변경만 기준 브랜치에 반영하는 절차**입니다.

## 기본 전략

- 기본 브랜치는 `main`입니다.
- MVP 초기에는 작은 PR 단위로 `main`에 머지합니다.
- 머지 방식은 `Squash and merge`를 기본값으로 둡니다.
- `main` 직접 푸시는 금지하고 PR 머지를 통해서만 반영합니다.

## 머지 전 필수 조건

- PR 주 목적이 하나이고 변경 범위가 [pr-rules.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/pr-rules.md)의 `PR 범위 경계`를 통과
- PR 본문 체크리스트 완료
- 작업 시작 체크포인트와 PR 범위 판단이 일치
- 담당 에이전트 검사 `PASS`
- [pr-review-gate.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/pr-review-gate.md) 기준 자체 리뷰 결과가 `PASS` 또는 허용 가능한 `COMMENT`
- 관련 문서 최신화
- 테스트 통과
- CI 체크리스트 통과
- 충돌 없음
- 저장소 보호 규칙이 요구하는 승인 수 충족
- 배포 영향이 있으면 `cd-checklist.md`, `deploy-runbook.md`, `release-checklist.md` 확인
- 서브 에이전트 작업이면 handoff 확인
- PR 실패 Issue가 있으면 해결 또는 후속 이슈 연결 확인

## Squash 커밋 메시지

형식:

```text
<type>(<scope>): <summary>

Refs: REQ-xx, AC-xx, TC-xx
Docs: <changed-doc-path>
```

예시:

```text
feat(api): 이력서 진단 API 추가

Refs: REQ-01, AC-01, TC-01
Docs: specs/2026-05-21-0943-ai-resume-diagnoser/api-spec.md
```

## 머지 금지 조건

- 테스트 실패
- CI 체크리스트 미확인
- PR 주 목적과 무관한 CI/운영/템플릿/광범위 문서 정리 포함
- 문서 드리프트 존재
- PR 범위 초과 변경 포함
- 보안 정보 노출
- 배포 절차 미확인 상태에서 운영 영향 있는 변경
- 문서와 구현 불일치
- 에이전트 권한 위반 또는 handoff 누락
- 자체 리뷰 결과 `REQUEST_CHANGES` 존재
- 해결되지 않은 PR 실패 Issue 존재

## 머지 후 작업

- 필요 시 릴리즈 체크리스트 갱신
- `main` 반영 후 GitHub Actions 결과 확인
- CI/CD 기준이 바뀌었으면 [ci-checklist.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/ci-checklist.md) 또는 [cd-checklist.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/cd-checklist.md) 갱신
- 배포 대상이면 [release-checklist.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/release-checklist.md) 확인
- 장애 가능성이 있으면 [incident-playbook.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/incident-playbook.md) 확인
- 다음 작업이 있으면 [agent-handoff-template.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/agent-handoff-template.md) 기준 handoff 확인
- 머지 후 짧은 운영 기록으로 무엇을 머지했고 어떤 체크를 통과했는지 남김

## 핫픽스 예외

운영 장애 대응은 빠른 머지를 허용합니다. 단, 머지 후 반드시 문서와 테스트를 보강합니다.

핫픽스 후속 작업:

- 원인 기록
- 재발 방지 테스트 추가
- 관련 표준 또는 운영 문서 갱신
