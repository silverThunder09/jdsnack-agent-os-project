- 구현 상태: `active`

### T1. 입력 및 결과 화면 디자인 개선

- 상태: `in_progress`
- 범위: REQ-01~REQ-03, 입력·결과 화면과 공통 스타일, 관련 테스트.
- 의존성: 없음. 원격 main 기준 격리 Worktree.
- 완료 조건: AC-01~AC-03 및 TC-01~TC-03, frontend lint/test/build/E2E 및 Compose health/smoke, 리뷰 게이트.
- 작업 시작 체크포인트: Standard. frontend/src 및 관련 E2E·spec만 수정. API/DB/CI/배포 정책 제외. archive·빌드 산출물·secret 탐색 제외. 기존 계약 보존, 단일 UI PR.
