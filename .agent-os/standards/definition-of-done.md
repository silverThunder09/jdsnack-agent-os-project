# 완료 정의

## 핵심 요약

“코드가 돌아간다”는 완료가 아닙니다.  
JDSnack에서 완료는 **문서, 테스트, 구현, 검증이 서로 맞물린 상태**를 뜻합니다.

## 역할 기준

- 완료 판단, PR 리뷰, 머지 가능 여부 판단은 클로드가 담당합니다.
- 코덱스는 구현 완료, 테스트 실행, 리뷰 기반 코드 수정 결과를 클로드가 판단할 수 있게 정리합니다.

## 완료 체크리스트

모든 작업은 아래 항목을 충족해야 완료로 간주합니다.

- 관련 기능 명세 문서가 갱신되었다.
- `acceptance-criteria.md`가 실제 변경을 반영한다.
- `test-scenarios.md`가 실제 검증 경로를 반영한다.
- `traceability.md`에 요구사항과 테스트 연결이 있다.
- 코드 구현이 완료되었다.
- 테스트 또는 검증 절차가 수행되었다.
- `frontend/` 또는 `backend/` 코드 변경이면 Compose 이미지 재빌드·재실행과 컨테이너/health 확인이 완료되었다.
- 변경 범위에 맞는 CI 체크리스트가 확인되었다.
- 배포 영향이 있으면 CD 체크리스트가 확인되었다.
- 변경 이유가 `standards/` 문서와 충돌하지 않는다.
- 커밋, PR, 머지 규칙이 Git 운영 표준과 충돌하지 않는다.
- PR 작업이면 [pr-review-gate.md](../operations/pr-review-gate.md) 기준 자체 리뷰 결과가 남아 있다.

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

- [ci-checklist.md](../operations/ci-checklist.md) 갱신
- 배포 영향이 있으면 [cd-checklist.md](../operations/cd-checklist.md) 갱신
- PR/머지 규칙과 충돌하지 않는지 확인

## 리뷰 기준

리뷰에서는 아래를 코드 버그와 같은 급으로 취급합니다.

- 문서 누락
- 테스트 연결 누락
- 경계 규칙 위반
- 구현과 문서의 계약 불일치
- CI/CD 체크 누락
- 커밋/PR/머지 규칙 누락
- 자체 리뷰 게이트 누락 또는 `REQUEST_CHANGES` 미해결
