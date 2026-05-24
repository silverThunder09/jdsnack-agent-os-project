# 커스텀 에이전트 TOML 전환 테스트 시나리오

## `TC-01` TOML 파일 구조 확인

- 대응 AC: `AC-01`
- 절차:
  - `.codex/agents/*.toml` 파일을 확인한다.
- 기대 결과:
  - 7개 TOML 파일이 존재한다.
  - 각 파일에 `name`, `description`, `instructions`가 있다.

## `TC-02` 구 MD 프롬프트 제거 확인

- 대응 AC: `AC-02`
- 절차:
  - `.agent-os/agents/*.md` 존재 여부를 확인한다.
- 기대 결과:
  - 구 MD 프롬프트 파일이 남아 있지 않다.

## `TC-03` 진입 문서 참조 확인

- 대응 AC: `AC-03`
- 절차:
  - `AGENTS.md`와 `README.md`의 에이전트 안내를 확인한다.
- 기대 결과:
  - 실제 커스텀 에이전트 위치가 `.codex/agents/`로 표시된다.

## `TC-04` 쓰레드별 에이전트 호출 기준 확인

- 대응 AC: `AC-04`
- 절차:
  - `AGENTS.md`, `sub-agent-operations.md`, `pr-automation-loop.md`, `pr-review-gate.md`를 확인한다.
- 기대 결과:
  - 계획 쓰레드는 `Spec Steward`, 개발 쓰레드는 구현 담당 에이전트, 검증 쓰레드는 `QA Reviewer`가 기본값으로 표시된다.
  - 조건부 에이전트는 실제 위험이 있을 때만 추가하도록 표시된다.
  - 모든 에이전트를 항상 동시에 호출하라는 규칙이 없다.
