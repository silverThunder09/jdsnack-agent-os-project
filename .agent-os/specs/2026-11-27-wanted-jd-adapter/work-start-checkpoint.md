# Work Start Checkpoint

## Target Spec
- .agent-os/specs/2026-11-27-wanted-jd-adapter

## Risk Level
- High-risk: 외부 URL 수집과 이미지 요청, redirect·SSRF 경계를 변경한다.

## Change Scope
- Wanted URL 식별, 전용 본문 추출, OCR allowlist, snapshot 출처 메타데이터, fixture 회귀 테스트.
- 로그인, 지원 자동화, 비밀값, CI/배포 설정은 제외한다.

## Read Scope
- AGENTS.md, JD adapter/OCR, 분석 snapshot/history, 프론트 URL 판별, PR·테스트 규칙.

## Do Not Read
- archive 전체, node_modules, build, dist, .git.

## Test Plan
- Wanted HTML·Next.js JSON·종료 공고·노이즈·URL·redirect·OCR·snapshot 테스트.
- 백엔드 테스트, 프론트 테스트/lint/build, Docker compose 및 smoke.

## PR Scope
- #236 원티드 JD source adapter 단일 기능과 직접 연결된 계약·테스트·문서.
- CI·배포 정책 변경은 포함하지 않는다.
