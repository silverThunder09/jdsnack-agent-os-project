# Frontend

## Purpose

React/Vite SPA가 공개 홈, 인증 게이트, 이력서·JD 분석 흐름과 결과 UI를 담당합니다. 컴포넌트는 화면을 그리고, hooks는 요청 상태를, services는 API 호출을 맡습니다.

## Key files

- `src/App.tsx`: 분석 입력·결과·모의면접 화면 조합
- `src/components/AuthGate.tsx`: 비로그인 UI와 보호 기능 경계
- `src/hooks/useDiagnose.ts`: 파일 진단 요청 상태
- `src/hooks/useMatchPreview.ts`: JD 수집·매칭 요청 상태
- `src/services/api.ts`: 백엔드 API 호출 전담

## Patterns

- 새 API는 `src/services/`에 추가하고 hook으로 감싼 뒤 컴포넌트에서 사용합니다.
- UI 상태 변경은 `App.test.tsx` 또는 가까운 component test로 회귀를 고정합니다.
- 보호 API는 `credentials: 'include'`를 유지하고 로그인 전에는 호출하지 않습니다.

## Gotchas

- 컴포넌트에서 직접 `fetch`를 호출하지 않습니다.
- Gemini key·OAuth secret은 프론트 환경 변수나 LocalStorage에 저장하지 않습니다.
- JD 링크 수집은 지원 사이트 외에는 본문 붙여넣기 흐름을 사용합니다.

## Dependencies

- 백엔드 API: [`src/services/api.ts`](src/services/api.ts)
- UI 계약: [`../.agent-os/specs/2026-07-18-service-mvp/ui-spec.md`](../.agent-os/specs/2026-07-18-service-mvp/ui-spec.md)
- 아키텍처: [`../docs/architecture/frontend-architecture.md`](../docs/architecture/frontend-architecture.md)

## Commands

```bash
npm ci
npm run lint
npm test
npm run build
npm run test:e2e
```
