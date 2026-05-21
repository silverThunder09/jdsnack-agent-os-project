# 통합 아키텍처

## 핵심 요약

이 문서는 프론트, 백엔드, 배포 단위를 어떻게 연결할지 설명합니다.  
비유하면 각 부품의 연결 규격을 정한 “조립 설명서”입니다.

## 통합 원칙

- React 빌드 결과물을 Spring Boot 정적 리소스로 포함합니다.
- 배포 단위는 단일 JAR를 기본값으로 둡니다.
- 로컬 개발에서는 프록시 또는 개발용 CORS 설정을 허용합니다.
- 운영 환경에서는 동일 오리진 구성을 기본값으로 둡니다.

## 런타임 흐름

1. 사용자가 SPA에 접속합니다.
2. React가 `/api/diagnose`를 호출합니다.
3. Spring Boot가 입력값을 검증합니다.
4. 유효한 입력이면 `AI_ANALYSIS_NOT_ENABLED` 준비중 응답을 반환합니다.
5. 프론트가 준비중 안내를 렌더링합니다.

## 운영 문서 연결

- 릴리즈 체크리스트: [.agent-os/operations/release-checklist.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/release-checklist.md)
- 배포 런북: [.agent-os/operations/deploy-runbook.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/deploy-runbook.md)
- 장애 대응: [.agent-os/operations/incident-playbook.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/incident-playbook.md)
