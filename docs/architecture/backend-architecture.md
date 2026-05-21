# 백엔드 아키텍처

## 핵심 요약

백엔드는 “주문을 받는 창구(Controller)”와 “실제 일을 처리하는 작업실(Service)”를 나누는 구조입니다.  
공식적으로는 **레이어드 아키텍처**이며, 현재 기준 핵심 경계는 `Controller -> Service -> External API`입니다.

## 레이어

- `controller`
  - HTTP 요청/응답 처리
  - 요청 검증
  - 공통 응답 래퍼 반환
- `service`
  - 프롬프트 구성
  - Gemini API 호출
  - 응답 파싱과 예외 변환
- `dto`
  - 요청/응답 스키마
  - 경계 데이터 전달용 record
- `exception`
  - 사용자 친화적 예외 응답
- `config`
  - 웹 설정, Gemini 설정, 환경별 정책

## 하네스 규칙

- Controller는 Service만 의존합니다.
- Service는 Controller를 의존하지 않습니다.
- DTO는 Controller 또는 퍼사드 경계에서만 사용합니다.
- 외부 API 응답은 Service 경계에서 검증/파싱합니다.
- 구조 변경 시 [.agent-os/standards/coding-standards.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/standards/coding-standards.md)를 함께 갱신합니다.

## 관련 문서

- API 계약: [.agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/api-spec.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/api-spec.md)
- 테스트 기준: [.agent-os/standards/testing-standards.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/standards/testing-standards.md)
