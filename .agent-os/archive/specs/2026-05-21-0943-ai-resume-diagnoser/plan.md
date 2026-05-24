# 1차 MVP 개발 계획

> 목표: 사용자 인증 정보 입력과 외부 AI 연동 없이, 이력서 입력/검증/API/UI 흐름을 먼저 완성한다.

## Task 1: 문서 계약 정리 - [진행 중]

- 1차 MVP 범위를 입력 검증과 준비중 안내로 고정한다.
- 인증 정보 입력, 외부 AI 호출, AI 결과 생성은 2차 MVP로 이동한다.
- `requirements`, `acceptance-criteria`, `test-scenarios`, `traceability`, `api-spec`, `ui-spec`, `architecture`를 같은 기준으로 맞춘다.

## Task 2: Spring Boot 백엔드 스캐폴딩

- Spring Boot 3.x 프로젝트를 `backend/`에 생성한다.
- `GET /api/health`를 구현한다.
- `POST /api/diagnose`를 구현한다.
- 입력 검증 실패 시 `400` 에러 코드를 반환한다.
- 입력 검증 성공 시 `501 AI_ANALYSIS_NOT_ENABLED`를 반환한다.

## Task 3: React 프론트엔드 스캐폴딩

- React + Vite + TypeScript 프로젝트를 `frontend/`에 생성한다.
- 이력서 입력 textarea, 글자 수 카운터, 진단 요청 버튼을 구현한다.
- 인증 정보 설정 UI는 만들지 않는다.
- 준비중 응답을 사용자 친화적 안내 카드로 렌더링한다.

## Task 4: 통합 검증

- 프론트에서 백엔드 `POST /api/diagnose`를 호출한다.
- 빈 입력, 짧은 입력, 긴 입력, 정상 입력 준비중 응답을 확인한다.
- 문서의 `AC`와 `TC`가 실제 동작과 일치하는지 확인한다.

## Task 5: 후속 확장 준비

- 2차 MVP에서 외부 AI 연동을 추가할 수 있도록 서비스 계층 경계를 유지한다.
- 단, 1차 MVP 코드에는 외부 AI 설정과 비밀값을 넣지 않는다.
