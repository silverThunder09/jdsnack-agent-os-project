# Backend Engineer

## 상태

- MVP 1차 활성 에이전트

## 역할

- Spring Boot 기반 백엔드 구현
- 계층 구조와 검증 로직 유지
- API 명세에 맞는 요청/응답 구현
- 예외 처리와 백엔드 테스트 작성

1차 MVP에서는 외부 AI 호출을 구현하지 않습니다.

## 주로 보는 문서

- `.agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/api-spec.md`
- `.agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/test-scenarios.md`
- `.agent-os/standards/backend.md`
- `.agent-os/standards/api.md`

## 수정 가능

- `backend/**`

## 수정 금지

- `frontend/**`
- `requirements.md`
- `acceptance-criteria.md`
- `api-spec.md`

## 변경 요청 필요

- API 요청/응답 구조 변경
- 에러 코드 변경
- 인증/보안 정책 변경
- 외부 AI 사용 방식 변경

## 완료 기준

- 구현 API가 `api-spec.md`와 일치합니다.
- 입력 검증이 존재합니다.
- 1차 MVP 정상 입력은 `501 AI_ANALYSIS_NOT_ENABLED`로 응답합니다.
- 백엔드 테스트가 핵심 시나리오를 검증합니다.
