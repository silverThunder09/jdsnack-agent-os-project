# 로컬 AI Compose 런타임 수용 기준

## `AC-01` compose ai-local 모드

- `compose.yaml`의 백엔드 기본 환경 변수는 `JDSNACK_DIAGNOSIS_MODE=ai-local`이어야 한다.
- CI smoke는 `JDSNACK_DIAGNOSIS_MODE=fixture`로 override할 수 있어야 한다.

## `AC-02` 선택적 `.env` 참조

- compose는 루트 `.env`를 참조한다.
- `.env`가 없어도 CI에서 compose 설정 검증이 실패하지 않아야 한다.

## `AC-03` 비밀값 안전성

- `.env`는 git 추적 대상이 아니어야 한다.
- `.env.example`만 예시로 유지한다.
- 실제 키 값은 어떤 문서나 코드에도 기록하지 않는다.
