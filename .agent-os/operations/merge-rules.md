# 머지 규칙

## 목적

머지는 “코드 합치기”가 아니라 **완료 정의를 통과한 변경만 기준 브랜치에 반영하는 절차**입니다.

## 기본 전략

- 기본 브랜치는 `main`입니다.
- MVP 초기에는 작은 PR 단위로 `main`에 머지합니다.
- 머지 방식은 `Squash and merge`를 기본값으로 둡니다.

## 머지 전 필수 조건

- PR 본문 체크리스트 완료
- 관련 문서 최신화
- 테스트 통과
- 충돌 없음
- 리뷰 승인 1명 이상
- 배포 영향이 있으면 `operations/` 문서 확인
- 서브 에이전트 작업이면 handoff 확인

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
- 문서 드리프트 존재
- PR 범위 초과 변경 포함
- 보안 정보 노출
- 배포 절차 미확인 상태에서 운영 영향 있는 변경
- 문서와 구현 불일치
- 에이전트 권한 위반 또는 handoff 누락

## 머지 후 작업

- 필요 시 릴리즈 체크리스트 갱신
- 배포 대상이면 [release-checklist.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/operations/release-checklist.md) 확인
- 장애 가능성이 있으면 [incident-playbook.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/operations/incident-playbook.md) 확인
- 다음 작업이 있으면 [agent-handoff-template.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/operations/agent-handoff-template.md) 기준 handoff 확인

## 핫픽스 예외

운영 장애 대응은 빠른 머지를 허용합니다. 단, 머지 후 반드시 문서와 테스트를 보강합니다.

핫픽스 후속 작업:

- 원인 기록
- 재발 방지 테스트 추가
- 관련 표준 또는 운영 문서 갱신
