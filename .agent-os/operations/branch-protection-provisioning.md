# Branch protection provisioning

이 문서는 `main` 브랜치에 필요한 GitHub Pull Request 보호 설정을
프로비저닝하고 실제 적용 상태를 확인하는 운영 절차입니다.

## 필수 상태

- `main`에는 Pull Request 리뷰 보호가 설정되어 있어야 합니다.
- GitHub API의
  `repos/$REPOSITORY/branches/$BASE_BRANCH/protection` 응답이 존재해야
  합니다.
- `required_pull_request_reviews` 설정이 존재하고
  `required_approving_review_count`는 최소 1이어야 합니다.
- 기존 required status checks는 보존해야 합니다. 설정을 덮어쓰기 전에
  현재 보호 설정과 check 목록을 캡처하고, 적용 후 동일한 목록이 유지되는지
  확인합니다.
- 저장소 설정에서는 stale review dismissal을 활성화해야 하며, 승인 게이트도
  `dismiss_stale_reviews=true`가 아니면 `needs-human`으로 중단합니다.
  승인 게이트는 이 설정과 별개로 최신 review state와 현재 head SHA를
  다시 확인하므로, 이전 head의 승인을 현재 head 승인으로 재사용하지
  않습니다.

## 위험도별 승인 계약

`scripts/complete-review-approval.ps1`이 branch protection을 live
검증 지점으로 사용합니다.

- Light: 최신 head의 유효한 사람 승인 1명 이상.
- Standard: 최신 head의 유효한 사람 리뷰를 확인하되 자동 병합은
  별도 정책과 CI 조건을 만족할 때만 진행합니다.
- High-risk: 최신 head 이후 사람 승인 2명 이상과 저장소 소유자의
  최신 head 기준 Squash auto-merge 확인이 필요합니다.
- 보호 설정 조회가 실패하거나 required pull request review 보호가 없으면
  승인 job은 `needs-human` 경계로 중단합니다.

## 관리자 프로비저닝 및 확인

저장소 소유자 또는 관리자 권한으로 GitHub Repository settings에서
`main`의 Pull Request protection을 설정합니다. required status checks를
임의로 삭제하거나 빈 목록으로 덮어쓰지 않습니다.

적용 전후에는 다음 명령으로 live 상태를 확인합니다.

```bash
REPOSITORY=owner/name
BASE_BRANCH=main

gh api "repos/$REPOSITORY/branches/$BASE_BRANCH/protection"
gh api "repos/$REPOSITORY/branches/$BASE_BRANCH/protection/required_pull_request_reviews"
```

두 번째 응답에서 `required_approving_review_count`와 stale review
설정을 확인하고, 첫 번째 응답에서 required status checks와 branch
보호가 실제로 활성화되어 있는지 확인합니다. 확인 대상 저장소와
브랜치는 승인 job에 전달되는 `Repository`와 `BaseBranch`와 같아야
합니다.

## 변경 후 검증

1. 보호 설정 응답을 저장해 변경 전후를 비교합니다.
2. `scripts/complete-review-approval.ps1`의 승인 계약 테스트와
   `scripts/codex-branch-review-workflow-test.sh`를 실행합니다.
3. PR의 base/head SHA, 필수 CI check, 리뷰의 commit SHA를 다시 확인합니다.
4. high-risk PR이면 저장소 소유자가 최신 head에서 Squash auto-merge를
   명시적으로 확인한 뒤에만 approval job을 재실행합니다.
