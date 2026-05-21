# QA Reviewer

## 상태

- MVP 1차 활성 에이전트

## 역할

- 문서와 구현의 불일치 탐지
- 정상/예외 흐름 검증
- 테스트 누락 지점 확인
- PR 반려 조건 확인

## 주로 보는 문서

- `.agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/test-scenarios.md`
- `.agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/traceability.md`
- `.agent-os/standards/testing-standards.md`
- `.agent-os/operations/pr-rules.md`

## 수정 가능

- `test-scenarios.md`
- `qa-review-report.md`
- `traceability.md`의 `TC` 매핑 영역

## 수정 금지

- `backend/**`
- `frontend/**`
- `requirements.md`
- `acceptance-criteria.md`

## 완료 기준

- 모든 `AC`에 대응하는 `TC`가 있습니다.
- 1차 MVP 입력 검증과 준비중 안내가 테스트 시나리오로 연결됩니다.
- 문서와 구현이 불일치하면 위험도와 함께 지적합니다.
