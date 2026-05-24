# 1차 MVP 일정

> 목표: 이력서 입력, 검증 API, 준비중 안내 UI까지 구현한다.

## M0. 문서 계약 정리

- 1차 MVP 범위를 입력 검증과 준비중 안내로 고정
- 외부 AI 연동을 2차 MVP로 이동
- API/UI/테스트 계약 동기화

## M1. 백엔드 스캐폴딩

- Spring Boot 프로젝트 생성
- `GET /api/health` 구현
- `POST /api/diagnose` 구현
- 입력 검증 실패 응답 구현
- 정상 입력 시 `AI_ANALYSIS_NOT_ENABLED` 응답 구현

## M2. 프론트엔드 스캐폴딩

- React + Vite + TypeScript 프로젝트 생성
- 이력서 입력 화면 구현
- 글자 수 카운터 구현
- 진단 요청 버튼 구현
- 준비중 안내 카드 구현

## M3. 통합 검증

- 프론트에서 백엔드 API 호출
- 빈 입력, 짧은 입력, 긴 입력, 정상 입력 시나리오 확인
- 문서의 `AC`, `TC`와 실제 동작 비교

## M4. 후속 준비

- 2차 MVP에서 외부 AI 연동을 추가할 수 있도록 Service 경계 유지
- 단, 1차 MVP에는 외부 AI 설정과 비밀값을 넣지 않음

## 1차 MVP 완료 기준

- `GET /api/health`가 정상 응답한다.
- `POST /api/diagnose`가 입력 검증을 수행한다.
- 정상 입력에 대해 `501 AI_ANALYSIS_NOT_ENABLED`가 반환된다.
- 프론트에서 준비중 안내가 표시된다.
- 인증 정보 입력 UI가 없다.
