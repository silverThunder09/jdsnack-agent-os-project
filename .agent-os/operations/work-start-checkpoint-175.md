# Work Start Checkpoint

## Target Spec
- 대상 spec: `.agent-os/adr/adr-019-postgresql-service-storage.md` 및 Issue #175
- 활성 feature spec: 없음 (`.agent-os/standards/index.yml`의 `active_specs`가 비어 있음)

## Risk Level
- `High-risk`
- PostgreSQL 운영 저장소와 DB 마이그레이션 경로를 변경하므로 데이터·배포 영향이 있습니다.

## Change Scope
- 이번 작업에서 바꾸는 것: PostgreSQL 프로파일의 영속 스키마 초기화 경로, 마이그레이션 도구 결정/문서, 관련 테스트와 CI 검증, Windows UTF-8 초기화 회귀
- 이번 작업에서 바꾸지 않는 것: 운영 DB 전환·백업/복구 실행, API/UI 계약, 인증 로직, 브랜치 보호와 리뷰/머지 정책

## Read Scope
- 반드시 읽을 문서/폴더: ADR-019, backend datasource/schema/tests, PR CI router, PR/merge rules
- 필요할 때만 읽을 문서/폴더: 상세 DB 운영 문서와 archive

## Do Not Read
- 기본 탐색 제외: `frontend/node_modules`, `frontend/dist`, `backend/build`, `backend/.gradle`, `.agent-os/archive`, `.git`
- 예외적으로만 확인할 범위: 운영 배포 문서는 실제 compose/DB 전환 계약이 변경될 때만 확인

## Test Plan
- 로컬 테스트: PostgreSQL 마이그레이션 SQL 검증, H2 전체 회귀, backend `bootJar`
- 수동 검증: Docker Compose 재빌드·컨테이너 상태·`/api/health`, 필요 시 PostgreSQL 프로파일 기동 확인
- CI 기대 항목: backend test/build, 실제 PostgreSQL migration apply/idempotency, PR CI Gate

## PR Scope
- PR 주 목적: Issue #175의 PostgreSQL 영속 스키마 마이그레이션 경로를 구현한다.
- 같은 PR에 포함할 항목: 구현에 직접 필요한 테스트·ADR·CI 검증 및 UTF-8 회귀 수정
- 별도 PR로 분리할 항목: Issue #190의 인증 High-risk PR 머지/사람 승인 처리
