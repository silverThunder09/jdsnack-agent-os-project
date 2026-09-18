- 구현 상태: `in-progress`

### T1. 백엔드 JobKorea 수집 어댑터

- 상태: `completed`
- 범위: host allowlist 확장, `sourceSite=jobkorea` 판정, fixture 기반 후보 selector·noise 규칙, 실패 error code 매핑, SSRF·timeout·본문 상한 재사용, JobKorea fixture 4종 추가
- 의존성: 없음
- 완료 조건: AC-01~AC-09와 TC-01~TC-10을 포함한 `./gradlew test` 통과, 사람인 회귀 유지, 새 error code·새 endpoint 없음
- 검증: `cd backend && .\\gradlew.bat test` 통과, `python scripts/check-ai-readiness.py` 통과, `python scripts/autonomous_spec_loop.py validate` 통과. Docker CLI 미설치로 Compose/health 검증은 미실행.

### T2. JobKorea 링크 분석 이력 출처 식별

- 상태: `pending`
- 범위: `JdInputType.JOBKOREA_URL` 추가, URL 입력 타입의 서버 수집 분기와 `sourceUrl`·`sourceSite`·`fetchMode` 서버 정본 저장, 기존 `SARAMIN_URL` 하위 호환
- 의존성: T1
- 완료 조건: AC-10과 TC-11·TC-12를 포함한 `./gradlew test` 통과, migration 없이 통과, quota·idempotency 계약 무변경
- 검증: 미실행

### T3. 프론트 출처 판별과 실패 안내

- 상태: `pending`
- 범위: JD 링크 host 기반 `inputType`·`sourceSite` 전송, 지원 사이트 안내 문구에 JobKorea 추가, error code별 수집 실패 안내 구분
- 의존성: T2
- 완료 조건: AC-11과 TC-13·TC-14를 포함한 frontend lint·test·build 통과, 컴포넌트 직접 fetch 없음
- 검증: 미실행

Feature 전체 완료 시 이 Spec을 `.agent-os/archive/specs/`로 이동하고 `active_specs`를 비운다. 절차 정본은 [doc-lifecycle.md](../../standards/doc-lifecycle.md)다.
