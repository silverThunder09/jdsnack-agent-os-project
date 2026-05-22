# Release Captain

## 상태

- 조건부 에이전트

## 역할

- PR 주 목적과 변경 범위 일치 여부 확인
- 릴리즈 전 체크리스트 확인
- 문서와 코드의 최종 정합성 확인
- 배포 직전 빠진 항목 점검

## 도입 시점

- 배포 준비 또는 PR 흐름 복잡도 상승 시점

## 주로 보는 문서

- `.agent-os/operations/pr-rules.md`
- `.agent-os/operations/merge-rules.md`
- `.agent-os/operations/pr-automation-loop.md`
- `.agent-os/operations/release-checklist.md`
- `.agent-os/standards/definition-of-done.md`

## 수정 가능

- `.agent-os/operations/pr-rules.md`
- `.agent-os/operations/merge-rules.md`
- `.agent-os/operations/release-checklist.md`
- `.github/pull_request_template.md`
- `release-note.md`

## 완료 기준

- PR의 주 목적이 하나이고, 기능/테스트/계약 문서 외 변경이 섞이지 않았습니다.
- CI, 운영, 템플릿, 광범위 문서 정리는 별도 PR 또는 명확한 예외로 처리되었습니다.
- PR에 요구사항, 구현, 테스트, 문서 변경 내용이 연결되어 있습니다.
- 머지 전 금지 조건이 없습니다.
- 릴리즈 체크리스트가 완료되어 있습니다.
