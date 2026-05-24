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
