# 통합 아키텍처

## 핵심 요약

이 문서는 프론트, 백엔드, 배포 단위를 어떻게 연결할지 설명합니다.  
비유하면 각 부품의 연결 규격을 정한 “조립 설명서”입니다.

## 통합 원칙

- 프론트엔드와 백엔드는 분리 컨테이너로 배포합니다.
- 프론트 컨테이너는 SPA 제공과 사용자 진입점을 담당합니다.
- 백엔드 컨테이너는 `/api/**` 요청과 비즈니스 로직을 담당합니다.
- 로컬 개발에서는 프록시 또는 개발용 CORS 설정을 허용합니다.
- 운영 환경에서는 reverse proxy 또는 ingress로 프론트와 백엔드를 묶어 같은 서비스처럼 노출합니다.

## 런타임 흐름

1. 사용자가 SPA에 접속합니다.
2. 프론트 컨테이너가 API 요청을 백엔드 컨테이너로 전달합니다.
3. Spring Boot가 입력값을 검증합니다.
4. 유효한 입력이면 fixture/stub 또는 명시적 `ai-local` provider가 결과를 반환합니다.
5. 프론트가 결과 카드 또는 오류 상태를 렌더링합니다.

## Common changes and gotchas

- 로컬 검증은 `compose.local.yaml`, 배포 검증은 `compose.prod.yaml`을 사용합니다.
- 코드 변경은 compose 재빌드 후 health endpoint와 관련 smoke test까지 확인해야 합니다.
- 세션·Gemini key 같은 비밀값은 compose 로그·PR 본문·브라우저 저장소에 남기지 않습니다.

## 운영 문서 연결

- 릴리즈 체크리스트: [release checklist](../../.agent-os/operations/release-checklist.md)
- 배포 런북: [deploy runbook](../../.agent-os/operations/deploy-runbook.md)
- 장애 대응: [incident playbook](../../.agent-os/operations/incident-playbook.md)
