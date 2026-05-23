# 시스템 개요

## 핵심 요약

JDSnack은 Spring Boot API와 React 프론트를 **분리 컨테이너로 배포하는 아키텍처**를 채택합니다.
목표는 역할 분리, 독립 배포, 운영 확장성을 확보하는 것입니다.

## 시스템 구성

- 사용자 브라우저에서 React SPA 실행
- React가 `/api/diagnose`와 `/api/health` 호출
- 프론트 컨테이너가 SPA를 제공
- 백엔드 컨테이너가 REST API를 제공
- Spring Boot가 입력값을 검증하고 `stub` 또는 `fixture` 모드로 응답
- 1.5차 MVP 통합 런타임은 H2 fixture 데이터와 LocalStorage를 함께 사용

## 문서 역할

- 상세 백엔드 구조: [backend-architecture.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/docs/architecture/backend-architecture.md)
- 상세 프론트 구조: [frontend-architecture.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/docs/architecture/frontend-architecture.md)
- 통합/배포 구조: [integration-architecture.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/docs/architecture/integration-architecture.md)
- 원본 상세 문서: [.agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/architecture.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/architecture.md)

## 핵심 불변 조건

- 프론트와 백은 서로 다른 컨테이너로 동작합니다.
- 외부 공개 엔드포인트는 reverse proxy 또는 ingress 뒤에서 하나의 서비스처럼 노출할 수 있습니다.
- 1차 MVP에서는 외부 AI를 호출하지 않습니다.
- 2차 MVP에서 외부 AI 호출을 추가할 경우 백엔드 경계에서만 수행합니다.
- 프론트는 API 계약에만 의존하고 외부 AI 세부 구현은 모릅니다.
- 확장 전까지 데이터 영속화는 서버 DB가 아니라 로컬 저장소를 우선 사용합니다.
