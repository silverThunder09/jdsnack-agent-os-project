# JD 링크 to AI 매칭 안정화 계획

## Summary

JD 링크 수집 결과가 AI 매칭 리포트까지 끊기지 않게 이어지는 사용자 흐름을 안정화한다. 이번 spec은 수집 자체보다 `JD 링크 성공/실패 -> JD 본문 준비 -> 매칭 요청 -> 리포트 표시` 연결을 기준으로 한다.

## 변경 범위

- 새 active spec 추가
- 기존 사람인 JD 수집 안정화 spec archive 이동
- `AGENTS.md`, `.agent-os/standards/index.yml`, `README.md` active spec 갱신
- 구현과 검증 기록은 이 기획 스레드에서 관리

## 구현 지침

- JD 링크 성공/실패 상태와 textarea 보존/자동 채움 흐름을 확인한다.
- 기존 `POST /api/jd/fetch`와 `POST /api/match/preview` 계약을 유지한다.
- 브라우저 기준 성공 흐름과 실패 후 복구 흐름을 검증한다.
- Playwright smoke는 외부 사이트와 Gemini를 실제 호출하지 않고 route mock으로 UI 연결 흐름을 고정한다.
- 새 spec 폴더를 만들지 않고 이 active spec 안에서 브라우저 검증 기준만 확장한다.

## 제외 범위

- 새 API 추가
- Gemini 응답 스키마 변경
- 잡코리아/원티드 수집
- 로그인 우회 또는 anti-bot 우회
- 운영 배포 플랫폼 확정

## 컨테이너 운영 기준

- 로컬 개발/검증은 `compose.local.yaml`에서 `build:`로 소스 이미지를 빌드한다.
- 배포/운영 실행은 `compose.prod.yaml`에서 `image:`로 registry 이미지를 pull한다.
- PR 검증은 local build compose 기준으로 수행한다.
- `main` 반영 후에는 GitHub Container Registry에 backend/frontend 이미지를 push하고, prod compose pull 가능 여부를 확인한다.
