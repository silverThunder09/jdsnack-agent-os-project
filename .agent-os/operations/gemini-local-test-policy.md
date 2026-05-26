# Gemini 로컬 실호출 검증 정책

## 목적

Gemini 실호출 검증은 운영 AI 연동이 아니라, 로컬에서 외부 API 응답 형태와 화면 흐름을 확인하기 위한 제한된 검증입니다.

## 원칙

- API Key 이름은 `GEMINI_API_KEY`로 통일한다.
- `.env`는 로컬 전용이며 커밋하지 않는다.
- `.env.example`만 커밋한다.
- 기본 `test`와 CI는 `stub/fixture`만 실행한다.
- Gemini 실호출은 `./scripts/google-test.sh`를 통해서만 실행한다.
- `GEMINI_API_KEY`가 없으면 skip하지 않고 fail-fast 한다.
- `.env` 로드는 스크립트가 책임진다.
- 화면 검증은 `JDSNACK_DIAGNOSIS_MODE=ai-local`에서만 실제 Gemini 결과를 기대한다.
- Codex와 에이전트는 `.env` 내용을 읽거나 수정하지 않는다.

## 보안 기준

- API Key는 Google Cloud 또는 AI Studio에서 사용 범위를 제한한다.
- 사용량/결제 알림을 설정한다.
- 키 유출 시 즉시 폐기하고 재발급한다.
- 요청 헤더와 API Key를 로그에 출력하지 않는다.
- 테스트 응답 전체 원문을 로그에 출력하지 않는다.
- 실행 전 `.env`가 git stage 상태인지 확인한다.

## API 단독 검증

`./scripts/google-test.sh`는 로컬 실호출 단위 검증입니다.

기대 결과:

- `.env`가 없으면 fail-fast 한다.
- `GEMINI_API_KEY`가 없으면 fail-fast 한다.
- `.env`가 git tracked 또는 staged 상태면 fail-fast 한다.
- 성공 시 Gemini 응답이 내부 분석 결과 형태로 파싱되는지만 확인한다.

## 화면 수동 검증

사전 조건:

- 사용자가 직접 루트 `.env`에 `GEMINI_API_KEY`를 설정한다.
- 필요 시 `GEMINI_MODEL`을 설정한다.
- `.env`는 git tracked/staged 상태가 아니어야 한다.

실행:

```sh
docker compose -f compose.local.yaml up --build
```

브라우저 확인:

1. `http://localhost:5173`에 접속한다.
2. 이력서 텍스트를 입력하거나 PDF/DOCX를 업로드한다.
3. JD 본문을 직접 입력하거나 JD 링크를 불러온다.
4. `JD 비교 미리보기`를 실행한다.
5. 점수, 요약, 강점, 보완 포인트, 개선 제안이 표시되는지 확인한다.

키 누락 확인:

- `ai-local` 모드에서 `GEMINI_API_KEY`가 없으면 키 누락 안내가 표시되어야 한다.
- 키 누락은 정상적인 보안 실패로 간주한다.

로그 확인:

- API Key, Authorization header, Gemini 원문 전체 응답이 로그에 노출되면 안 된다.

## 운영 분리

`googleTest`와 `ai-local` 화면 확인은 로컬 검증입니다. 운영 AI 연동, 재시도, 타임아웃, 장애 대응, 사용자 데이터 정책은 별도 2차 MVP 설계에서 다룹니다.
