# Work Start Checkpoint

## Target Spec

- 대상 spec: `2026-09-18-jobkorea-jd-adapter`
- 대상 티켓: `T1` 백엔드 JobKorea 수집 어댑터

## Risk Level

- `High-risk`
- 외부 JobKorea URL fetch 경계와 SSRF·redirect·응답 크기 정책에 영향을 준다.
- 실서비스 호출과 인증정보는 사용하지 않고 fixture/mock HTTP만 사용한다.

## Change Scope

- JobKorea host allowlist와 `sourceSite=jobkorea` 판정
- fixture 기반 후보 selector·noise 제거·오류 페이지 판정
- 기존 SSRF·timeout·본문 상한·error code 계약의 JobKorea 회귀 검증
- JobKorea 정상·noise·본문 부족·오류/차단 fixture와 mock `HttpClient` 테스트

## Read Scope

- active spec의 requirements, acceptance-criteria, test-scenarios, traceability, api-spec, ui-spec, plan
- `backend/src/main/java/com/jdsnack/jd/` 수집 서비스·추출기·selector와 기존 사람인 fixture/test
- JD source adapter ADR, backend/API/testing standards, integration architecture, PR/merge rules

## Do Not Read or Change

- T2 `JdInputType.JOBKOREA_URL`과 분석 이력 저장
- T3 frontend 출처 판별과 실패 안내
- RocketPunch, Redis/비동기 worker, 결제·요금제, 실서비스 크롤링 우회
- JobKorea 실호출·로그인·세션·API key·브라우저 비밀값

## Test Plan

- `cd backend && ./gradlew test`
- `python scripts/check-ai-readiness.py`
- `python scripts/autonomous_spec_loop.py validate`
- PR CI: backend test, PR contract, PR review gate, PostgreSQL/migration 관련 체크
- Docker Desktop이 설치되어 있으면 `docker compose -f compose.local.yaml up -d --build`, 컨테이너 상태와 health endpoint 확인

## PR Scope

- PR 주 목적: 기존 JD fetch 경계에 JobKorea 출처를 fixture 기반으로 추가
- 같은 PR에 포함: backend 구현·회귀 테스트·JobKorea fixture와 직접 연결된 문서/traceability 갱신
- 별도 PR로 분리: T2 분석 이력 출처 저장, T3 frontend 출처 판별, CI/CD·Docker 운영 변경, 다른 채용 플랫폼
- 실서비스 외부 호출은 하지 않으며, High-risk이므로 Claude review gate와 사람 승인 조건을 적용한다.
