# 1차 social login은 Google OAuth/OIDC로 시작

```yaml
id: adr-015-oauth-provider
status: proposed
risk: High
author: Codex
approved_by:
related_specs: 2026-07-16-google-oauth-account
```

## Context

서비스 MVP에는 사용자 식별과 데이터 소유권이 필요하지만, 여러 social provider를 동시에 도입하면 인증 경계와 테스트 범위가 커집니다.

## Decision

1차 공급자는 Google OAuth 2.0/OpenID Connect로 한정합니다. 내부 계정은 provider와 분리하고 provider subject를 외부 식별자로 저장하며, 이후 공급자는 동일한 SocialLoginProvider 경계로 추가합니다.

## Alternatives considered

- Kakao 우선: 한국 사용자 접근성은 좋지만 1차 공급자로 고정할 필요는 없습니다.
- 다중 provider 동시 도입: 사용자 선택 폭은 늘지만 MVP 인증·계정 병합 복잡도가 증가합니다.
- 자체 비밀번호: credential 저장·복구·보안 책임이 추가됩니다.

## Consequences

- callback state·redirect allowlist·secret 서버 보관이 필수입니다.
- provider token과 내부 session을 분리합니다.
- provider 추가는 새 ADR 또는 superseding ADR 대상입니다.

## Approval rule

- High 위험 ADR은 사용자 명시 승인이 있기 전까지 구현을 시작하지 않습니다.
- 이 문서는 현재 technical decision 초안이며, 승인 후 본문을 직접 수정하지 않고 superseding ADR로 변경합니다.
