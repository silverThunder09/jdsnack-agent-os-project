# 작업 시작 체크포인트

## 작업명

- 사람인 JD 수집 안정화 스펙

## 위험도

- `Standard`

## 기본 에이전트

- `Spec Steward`

## 목표

- 사람인 JD 링크 수집에서 가짜 성공을 막는 성공/실패 기준을 문서로 고정한다.

## 변경 허용

- `.agent-os/specs/2026-05-24-saramin-jd-scraping-stabilization/**`
- `.agent-os/archive/specs/2026-05-24-custom-agent-toml/**`
- `AGENTS.md`
- `.agent-os/standards/index.yml`
- `README.md`

## 변경 금지

- `backend/**`
- `frontend/**`
- `.env`
- `.github/workflows/**`

## 검증

- Docs Harness equivalent local checks
- `git diff --check`

## Handoff

- 다음 담당: `Backend Engineer`
- 다음 작업: 기존 `JdHtmlExtractor`에서 사람인 selector와 노이즈 차단 로직을 스펙 기준으로 안정화한다.
