# 시스템 개요

## 핵심 요약

JDSnack은 Spring Boot와 React를 하나의 실행 단위로 묶는 **단일 JAR 아키텍처**를 채택합니다.  
목표는 빠른 MVP 개발, 단순한 배포, 낮은 운영 복잡도입니다.

## 시스템 구성

- 사용자 브라우저에서 React SPA 실행
- React가 `/api/diagnose`와 `/api/health` 호출
- Spring Boot가 REST API와 정적 리소스를 함께 서빙
- Spring Boot가 Google Gemini API를 호출해 진단 결과 생성
- 초기 MVP는 DB 없이 LocalStorage 중심으로 동작

## 문서 역할

- 상세 백엔드 구조: [backend-architecture.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/docs/architecture/backend-architecture.md)
- 상세 프론트 구조: [frontend-architecture.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/docs/architecture/frontend-architecture.md)
- 통합/배포 구조: [integration-architecture.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/docs/architecture/integration-architecture.md)
- 원본 상세 문서: [.agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/architecture.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/architecture.md)

## 핵심 불변 조건

- 프론트와 백은 같은 배포 단위 안에서 동작합니다.
- 외부 AI 호출은 백엔드 경계에서만 수행합니다.
- 프론트는 API 계약에만 의존하고 Gemini 세부 구현은 모릅니다.
- 확장 전까지 데이터 영속화는 서버 DB가 아니라 로컬 저장소를 우선 사용합니다.
