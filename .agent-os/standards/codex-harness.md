# Codex 하네스 표준

이 문서는 상세 운영 규칙을 다시 복사하지 않고, Codex가 작업을 시작할 때 지켜야 할 진입점과 검증 경계만 정의합니다.

## 작업 진입 순서

1. [`AGENTS.md`](../../AGENTS.md)를 읽습니다.
2. [`index.yml`](index.yml)의 `active_specs`와 [`spec-queue.json`](../product/spec-queue.json)을 읽습니다.
3. 현재 티켓의 `requirements.md` → `acceptance-criteria.md` → `test-scenarios.md` → API/UI 계약을 읽습니다.
4. 관련 코드·테스트만 탐색하고 구현합니다.
5. traceability, 테스트, CI, PR 게이트를 확인합니다.

## 불변 조건

- 한 시점에 active Feature Spec은 하나입니다.
- 한 번에 준비된 티켓 하나만 구현합니다.
- API/UI 계약 변경은 해당 spec 문서와 함께 변경합니다.
- 테스트 assertion을 약화하거나 검증 범위를 줄여 통과시키지 않습니다.
- `backend/` 또는 `frontend/` 코드 변경은 테스트·lint·build 후 Compose 재빌드, 컨테이너 상태, health endpoint까지 확인합니다.
- High-risk, 충돌, 필수 의존성 장애, 사람 판단이 필요한 큐 조건은 `needs-human`으로 멈춥니다.

## 탐색 경계

- 기본 탐색은 `rg --files`와 `rg`를 사용합니다.
- archive, 빌드 산출물, 의존성 폴더, `.env` 내용은 기본 컨텍스트에서 제외합니다.
- 상세 탐색 규칙은 [`agent-scan-policy.md`](../operations/agent-scan-policy.md)를 따릅니다.

## 자동화 경계

- Spec 선택·승격·완료 전이는 [`spec-queue.json`](../product/spec-queue.json)과 저장소의 event-driven autonomous loop 실행기가 담당합니다. 실행기와 workflow는 별도 구현 PR에서 연결합니다.
- 티켓 구현은 Codex, 문서 Spec 생성과 독립 리뷰·PR 게이트는 Claude가 담당합니다.
- 자동화가 판단할 수 없는 상태를 추측해 진행하지 않고, 상태·사유·재개 지점을 기록한 뒤 알립니다.

상세 완료 조건은 [`definition-of-done.md`](definition-of-done.md), Spec 생명주기는 [`doc-lifecycle.md`](doc-lifecycle.md), PR 운영은 [`pr-automation-loop.md`](../operations/pr-automation-loop.md)가 정본입니다.
