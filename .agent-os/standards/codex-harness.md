# Codex 하네스 표준

이 문서는 상세 운영 규칙을 다시 복사하지 않고, Codex가 작업을 시작할 때 지켜야 할 진입점과 검증 경계만 정의합니다.

## 작업 진입 순서

1. [`AGENTS.md`](../../AGENTS.md)를 읽습니다.
2. [`index.yml`](index.yml)의 `active_specs`와 [`spec-queue.json`](../product/spec-queue.json)을 읽습니다.
3. 현재 티켓의 `requirements.md` → `acceptance-criteria.md` → `test-scenarios.md` → API/UI 계약을 읽습니다.
4. 관련 코드·테스트만 탐색하고 구현합니다.
5. 새 작업이거나 이전 PR 머지 후라면 primary checkout의 `main` 동기화 상태를 확인하고, 필요 시 `scripts/sync-main-checkout.sh`를 실행합니다.
6. traceability, 테스트, CI, PR 게이트를 확인합니다.

## 불변 조건

- 한 시점에 active Feature Spec은 최대 하나입니다. 후보 시작 조건을 기다릴 때는 `active_specs: []`를 유지합니다.
- 한 번에 준비된 티켓 하나만 구현합니다.
- API/UI 계약 변경은 해당 spec 문서와 함께 변경합니다.
- 테스트 assertion을 약화하거나 검증 범위를 줄여 통과시키지 않습니다.
- `backend/` 또는 `frontend/` 코드 변경의 완료는 테스트 코드 통과만을 뜻하지 않습니다. 테스트·lint·build 후 Compose를 재빌드·재실행하고, 컨테이너 상태·health endpoint·`scripts/smoke-test.sh`의 프론트 프록시/API 흐름까지 확인합니다.
- acceptance criteria가 실제 화면 상호작용을 요구하면 `frontend` Playwright smoke 또는 동등한 브라우저 검증도 수행합니다. Compose smoke의 fixture 성공을 실제 외부 AI/Gemini 성공으로 과장하지 않습니다.
- 충돌, 필수 의존성 장애, 불명확한 리뷰 결과, 사람 판단이 필요한 큐 조건은 `needs-human`으로 멈춥니다. 위험도 구간만으로 중단하거나 추가 승인을 요구하지 않습니다.
- PR 리뷰어는 `scripts/review-policy.json`의 `primaryReviewer`를 따릅니다. 현재 Codex가 격리된 읽기 전용 환경에서 바로 리뷰합니다. Claude를 기본으로 설정한 경우 실행 불가·구조화 결과 누락/오류는 [리뷰 실행 규칙](../operations/review-backend-fallback.md)에 따라 Codex로 넘기며, 유효한 반려 판정은 그대로 유지합니다.

## 탐색 경계

- 기본 탐색은 `rg --files`와 `rg`를 사용합니다.
- archive, 빌드 산출물, 의존성 폴더, `.env` 내용은 기본 컨텍스트에서 제외합니다.
- 상세 탐색 규칙은 [`agent-scan-policy.md`](../operations/agent-scan-policy.md)를 따릅니다.

## 자동화 경계

- Spec 선택·승격·완료 전이는 [`spec-queue.json`](../product/spec-queue.json)과 [`autonomous-loop.yml`](../../.github/workflows/autonomous-loop.yml)이 담당합니다.
- 티켓 구현·테스트는 Codex, 문서 Spec 생성·PR 관리는 Claude가 담당합니다. 독립 리뷰는 configured reviewer가 수행하고, trusted approval job이 최신 SHA와 필수 게이트를 재확인해 자동 병합을 큐에 넣습니다.
- 자동화가 판단할 수 없는 상태를 추측해 진행하지 않고, 상태·사유·재개 지점을 기록한 뒤 알립니다.
- Claude 실행 장애·구조화 결과 오류와 유효한 리뷰 반려를 구분합니다. Codex 실행 실패·결과 오류는 `needs-human`으로 중단하고, 코드 리뷰 반려는 원래 변경요청 루프를 유지합니다.
- PR 머지 후 로컬 파일 동기화는 GitHub의 merge 이벤트만으로 자동으로 일어나지 않으므로, 머지 확인 뒤 primary checkout에서 fetch + fast-forward를 명시적으로 수행합니다.

상세 완료 조건은 [`definition-of-done.md`](definition-of-done.md), Spec 생명주기는 [`doc-lifecycle.md`](doc-lifecycle.md), PR 운영은 [`pr-automation-loop.md`](../operations/pr-automation-loop.md)가 정본입니다.
