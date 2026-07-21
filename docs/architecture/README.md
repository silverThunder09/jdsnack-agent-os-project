# 아키텍처 문서

이 폴더에는 JDSnack의 시스템 구조를 역할별로 나누어 보관합니다.

## 현재 문서

- `system-overview.md`: 전체 시스템 개요
- `backend-architecture.md`: Spring Boot 백엔드 구조
- `frontend-architecture.md`: React 프론트엔드 구조
- `integration-architecture.md`: 프론트/백엔드 통합 흐름

## 관련 문서

- 활성 기능 명세: 현재 없음. 완료 명세는 [`../../.agent-os/archive/specs/`](../../.agent-os/archive/specs/)
- 문서·경로 검증: [`../../scripts/check-ai-readiness.py`](../../scripts/check-ai-readiness.py)

구조·데이터 흐름이 바뀌면 `system-overview.md`의 Mermaid map을 갱신합니다.

> Note: API/UI 계약 변경은 활성 spec과 관련 테스트를 함께 확인합니다.
