# PR 리뷰 실행과 폴백

## 실행 순서

1. `.github/workflows/codex-branch-review.yml`은 `PR CI Router` 성공 뒤 trusted base에서 PR의 base/head SHA를 고정하고, head 코드는 checkout하거나 실행하지 않습니다.
2. 기본 리뷰어는 `scripts/review-policy.json`의 `primaryReviewer`가 정합니다. 현재 값은 `codex`이므로 Claude 호출을 기다리지 않고 Codex가 격리된 읽기 전용 환경에서 즉시 리뷰합니다.
3. 기본 리뷰어가 Claude로 설정된 경우 유효한 구조화 결과는 그대로 사용합니다. Claude 실행 불가·구독/인증/쿼터 오류·timeout 또는 결과 누락/형식 오류는 Codex 읽기 전용 리뷰로 넘깁니다. 유효한 `REQUEST_CHANGES`, `COMMENT`, `NEEDS_HUMAN`, 점수 미달은 backend 장애가 아니므로 Codex로 덮어쓰지 않습니다.
4. Codex 입력은 PR diff와 review 기준뿐입니다. Codex는 checkout 밖의 빈 임시 작업공간에서 도구 없이 실행하며 diff에 포함된 지시문을 따르지 않습니다. Codex 실행 실패나 Codex의 누락·잘못된 구조화 결과는 `needs-human`으로 중단합니다.

## 점수와 병합

- 구조화 리뷰는 `decision`, `score`(0~5), `risk`, `findings`, `review_summary`를 반환합니다. 자동 병합에는 `PASS`와 4/5 이상이 모두 필요합니다. `REQUEST_CHANGES`, `COMMENT`, `NEEDS_HUMAN`, 4점 미만은 병합을 막습니다.
- `review-risk.ps1`의 위험도 점수·구간은 표시 라벨과 검토 경로만 정합니다. 위험도 구간은 사람 승인 수, 점수 기준 또는 자동 병합 가능 여부를 바꾸지 않습니다.
- `dryRun=false`입니다. 현재 PR의 base/head SHA가 리뷰 보고서와 일치하고, `Validate PR contract`, `PR CI Gate`, GitHub가 요구한 모든 check가 현재 head에서 통과하며, 미해결 `CHANGES_REQUESTED`가 없을 때 approval job이 Squash auto-merge를 큐에 넣습니다.
- GitHub가 `skipping`으로 보고한 check는 [`scripts/pr-check-policy.ps1`](../../scripts/pr-check-policy.ps1)에 이름이 명시된 PR Router 경로 선택 job만 성공으로 인정합니다. PR 계약, `PR CI Gate`, `review`, 알 수 없는 필수 check의 skip은 계속 차단합니다.
- 추가 사람 승인 수는 이 저장소의 자동화 정책에서 0입니다. GitHub branch protection에 실제로 설정된 필수 승인 수가 0보다 크면 GitHub 보호 규칙은 그대로 존중합니다. 위험도 라벨만으로 사람 승인을 추가하지 않습니다.
- review workflow는 `workflow_run`의 기본 브랜치 SHA에서 실행되므로, job 완료 뒤 GitHub Actions `checks:write` 토큰으로 이름이 `review`인 check run을 정확한 PR head SHA에 게시·갱신합니다. 그 check와 필수 CI가 모두 통과해야 merge job이 계속됩니다.

## 중단 조건

- Codex 리뷰 실행 실패, Codex 구조화 결과 누락/오류, `NEEDS_HUMAN`, 비-PASS 판정, 4점 미만
- 리뷰 전후 base/head SHA 변경 또는 PR이 닫힘
- PR 계약·PR CI Gate·branch-required check 누락/실패, check provider 또는 GitHub API 확인 실패
- 미해결 `CHANGES_REQUESTED`, artifact 누락, Squash auto-merge 큐 등록 실패

`REQUEST_CHANGES`는 GitHub review로 한 번 제출하고 findings 전체를 보존합니다. 점수·판정이 통과해도 필수 check가 실패하면 자동 병합하지 않습니다.

## 안전 경계

- `pull_request_target`과 `workflow_run`은 trusted base의 workflow·script만 실행합니다. PR head의 스크립트, workflow, 설정은 실행하지 않습니다.
- Codex에게는 diff와 검토 기준만 전달하며 shell·git·gh·web·저장소 접근·쓰기 기능을 제공하지 않습니다.
- 리뷰 및 approval job은 각각 최신 PR SHA와 check 상태를 다시 확인합니다. Squash auto-merge 요청이 등록됐다는 사실만으로 완료로 보고하지 않습니다. `gh pr view`가 `MERGED`와 `mergedAt`을 반환해야 완료입니다.
- workflow 변경 PR의 새 리뷰 코드는 해당 PR 자체를 리뷰할 때 실행되지 않습니다. trusted base에 반영된 뒤 후속 PR부터 적용됩니다.
