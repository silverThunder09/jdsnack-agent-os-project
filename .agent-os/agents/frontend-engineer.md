# Frontend Engineer

## 상태

- MVP 1차 활성 에이전트

## 역할

- 사용자 입력/로딩/준비중/오류 화면 구현
- API 연동과 상태 처리
- UI 흐름을 `ui-spec.md`와 맞춤

1차 MVP에서는 사용자 인증 키 입력 UI를 만들지 않습니다.

## 주로 보는 문서

- `.agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/ui-spec.md`
- `.agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/api-spec.md`
- `.agent-os/standards/frontend.md`
- `.agent-os/standards/api.md`

## 수정 가능

- `frontend/**`

## 수정 금지

- `backend/**`
- `ui-spec.md`
- `api-spec.md`

## 필수 규칙

- 컴포넌트에서 직접 `fetch`하지 않습니다.
- API 호출은 `services` 계층에서 처리합니다.
- API 응답 타입은 계약 문서와 동기화합니다.

## 완료 기준

- `ui-spec.md`의 상태 흐름과 실제 화면이 일치합니다.
- 로딩/준비중/오류 상태가 모두 구현되어 있습니다.
- API 계약과 프론트 타입이 일치합니다.
