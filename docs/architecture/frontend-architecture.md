# 프론트엔드 아키텍처

## 핵심 요약

프론트엔드는 “화면을 그리는 컴포넌트”와 “상태를 다루는 훅”, “네트워크를 다루는 서비스”를 분리합니다.  
쉽게 말하면, 버튼과 카드가 직접 통신하지 않고 전담 창구를 통해 서버와 대화하게 만드는 구조입니다.

## 레이어

- `components`
  - 입력창, 결과 카드, 점수 게이지, 로딩 UI
- `hooks`
  - 진단 요청 상태 관리
  - 로딩, 성공, 실패 상태 전환
- `services`
  - 백엔드 API 통신 전담
- `types`
  - 백엔드 계약과 맞춘 타입 정의
- `styles`
  - 디자인 토큰과 글로벌 스타일

## 하네스 규칙

- 컴포넌트에서 직접 `fetch`를 호출하지 않습니다.
- API 호출은 `services/api.ts` 또는 동등한 서비스 계층을 통해서만 수행합니다.
- 화면 렌더링 로직과 상태 전환 로직을 분리합니다.
- UI 흐름이 바뀌면 `ui-spec.md`와 `test-scenarios.md`를 함께 갱신합니다.

## Common changes and gotchas

- 새 API는 `services/` → hook → component 순서로 연결합니다. 컴포넌트의 직접 `fetch`는 금지합니다.
- 보호 API는 세션 쿠키를 위해 `credentials: 'include'`를 유지하고, `AuthGate`가 비로그인 호출을 막습니다.
- 비동기 화면 상태는 loading/success/error/not-enabled를 테스트로 고정합니다.

## 관련 문서

- UI 계약: [Service MVP UI spec](../../.agent-os/specs/2026-07-18-service-mvp/ui-spec.md)
- 기능 요구사항: [Service MVP requirements](../../.agent-os/specs/2026-07-18-service-mvp/requirements.md)
- 모듈 진입점: [frontend README](../../frontend/README.md)
