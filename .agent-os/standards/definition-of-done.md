# 완료 정의

## 핵심 요약

“코드가 돌아간다”는 완료가 아닙니다.  
JDSnack에서 완료는 **문서, 테스트, 구현, 검증이 서로 맞물린 상태**를 뜻합니다.

## 완료 체크리스트

모든 작업은 아래 항목을 충족해야 완료로 간주합니다.

- 관련 기능 명세 문서가 갱신되었다.
- `acceptance-criteria.md`가 실제 변경을 반영한다.
- `test-scenarios.md`가 실제 검증 경로를 반영한다.
- `traceability.md`에 요구사항과 테스트 연결이 있다.
- 코드 구현이 완료되었다.
- 테스트 또는 검증 절차가 수행되었다.
- 변경 범위에 맞는 CI 체크리스트가 확인되었다.
- 배포 영향이 있으면 CD 체크리스트가 확인되었다.
- 변경 이유가 `standards/` 문서와 충돌하지 않는다.
- 커밋, PR, 머지 규칙이 Git 운영 표준과 충돌하지 않는다.
- 서브 에이전트 작업이면 handoff가 남아 있다.
- PR 작업이면 [pr-review-gate.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/pr-review-gate.md) 기준 자체 리뷰 결과가 남아 있다.

## 문서별 완료 조건

### API 변경

- `api-spec.md` 갱신
- 성공/실패 응답 계약 반영
- 관련 시나리오 업데이트

### UI 변경

- `ui-spec.md` 갱신
- 상태 전환 또는 예외 흐름 반영
- 관련 시나리오 업데이트

### 요구사항 변경

- `requirements.md` 갱신
- `acceptance-criteria.md` 갱신
- `traceability.md` 갱신

### 표준 변경

- `standards/` 문서 반영
- 왜 승격했는지 이유 기록

### CI/CD 변경

- [ci-checklist.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/ci-checklist.md) 갱신
- 배포 영향이 있으면 [cd-checklist.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/cd-checklist.md) 갱신
- PR/머지 규칙과 충돌하지 않는지 확인

### 서브 에이전트 작업

- [sub-agent-operations.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/standards/sub-agent-operations.md)의 수정 권한을 지켰다.
- 작업 종료 시 [agent-handoff-template.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/agent-handoff-template.md) 형식으로 handoff를 남겼다.
- 영역 밖 변경 필요 사항은 직접 수정하지 않고 변경 요청으로 남겼다.

## 리뷰 기준

리뷰에서는 아래를 코드 버그와 같은 급으로 취급합니다.

- 문서 누락
- 테스트 연결 누락
- 경계 규칙 위반
- 구현과 문서의 계약 불일치
- CI/CD 체크 누락
- 커밋/PR/머지 규칙 누락
- 서브 에이전트 권한 위반 또는 handoff 누락
- 자체 리뷰 게이트 누락 또는 `REQUEST_CHANGES` 미해결
