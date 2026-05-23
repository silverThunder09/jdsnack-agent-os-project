# Gemini 로컬 실호출 테스트 정책

## 목적

Gemini 실호출 테스트는 운영 AI 연동이 아니라, 로컬에서 외부 API 응답 형태를 확인하기 위한 제한된 검증입니다.

## 원칙

- API Key 이름은 `GEMINI_API_KEY`로 통일한다.
- `.env`는 로컬 전용이며 커밋하지 않는다.
- `.env.example`만 커밋한다.
- 기본 `test`와 CI는 `stub/fixture`만 실행한다.
- Gemini 실호출은 `./scripts/google-test.sh`를 통해서만 실행한다.
- `GEMINI_API_KEY`가 없으면 skip하지 않고 fail-fast 한다.
- `.env` 로드는 스크립트가 책임진다.

## 보안 기준

- API Key는 Google Cloud 또는 AI Studio에서 사용 범위를 제한한다.
- 사용량/결제 알림을 설정한다.
- 키 유출 시 즉시 폐기하고 재발급한다.
- 요청 헤더와 API Key를 로그에 출력하지 않는다.
- 테스트 응답 전체 원문을 로그에 출력하지 않는다.
- 실행 전 `.env`가 git stage 상태인지 확인한다.

## 운영 분리

`googleTest`는 로컬 실호출 검증입니다. 운영 AI 연동, 재시도, 타임아웃, 장애 대응, 사용자 데이터 정책은 별도 2차 MVP 설계에서 다룹니다.
