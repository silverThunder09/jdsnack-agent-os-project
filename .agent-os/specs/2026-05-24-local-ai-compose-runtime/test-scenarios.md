# 로컬 AI Compose 런타임 테스트 시나리오

## `TC-01` compose 설정 검증

- 대응 AC: `AC-01`, `AC-02`
- 절차:
  - `docker compose config --no-interpolate`를 실행한다.
- 기대 결과:
  - compose 설정이 유효하다.
  - 백엔드 환경 변수에 `JDSNACK_DIAGNOSIS_MODE=ai-local`이 포함된다.
  - 실제 `.env` 값은 출력하지 않는다.

## `TC-02` `.env` 미추적 확인

- 대응 AC: `AC-03`
- 절차:
  - git 추적 파일과 ignore 규칙을 확인한다.
- 기대 결과:
  - `.env`는 추적되지 않는다.
  - `.env.example`은 유지된다.

## `TC-03` CI 회귀 확인

- 대응 AC: `AC-02`
- 절차:
  - PR에서 Docs Harness, Backend CI, Frontend CI, Container Flow를 확인한다.
- 기대 결과:
  - `.env`가 없는 CI 환경에서도 필수 체크가 통과한다.
