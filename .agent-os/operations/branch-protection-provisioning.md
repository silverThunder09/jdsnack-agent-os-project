# Branch protection provisioning

이 문서는 `main` 브랜치에 필요한 GitHub Pull Request 보호 설정을
프로비저닝하고 실제 적용 상태를 확인하는 운영 절차입니다.

## 필수 상태

- `main`에는 Pull Request 리뷰 보호가 설정되어 있어야 합니다.
- GitHub API의
  `repos/$REPOSITORY/branches/$BASE_BRANCH/protection` 응답이 존재해야
  합니다.
- `required_pull_request_reviews` 설정이 존재해야 합니다. 현재 개인 저장소 정책의
  `required_approving_review_count`는 0이며 위험도별 추가 승인도 없습니다. GitHub에
  나중에 0보다 큰 값이 설정되면 그 native 보호 규칙은 그대로 적용됩니다.
- 기존 required status checks는 보존해야 합니다. 설정을 덮어쓰기 전에
  현재 보호 설정과 check 목록을 캡처하고, 적용 후 동일한 목록이 유지되는지
  확인합니다.
- GitHub가 사람 승인을 요구하는 경우(`required_approving_review_count > 0`)에는 stale
  review dismissal을 활성화해야 합니다. 승인 게이트는 최신 review state와 현재 head
  SHA를 확인해 이전 head의 승인을 재사용하지 않습니다. 현재 승인 수가 0이면 stale
  review dismissal은 자동 병합 선행 조건이 아닙니다.

## 위험도별 승인 계약

`scripts/complete-review-approval.ps1`이 branch protection을 live
검증 지점으로 사용합니다.

- Light/Standard/High-risk 구간 모두 자동화가 추가로 요구하는 사람 승인은 0입니다.
  위험도 점수는 PR 라벨과 리뷰 경로에만 사용합니다.
- GitHub branch protection이 요구하는 승인 수가 0보다 크면 해당 승인 수를 확인하고,
  GitHub도 승인 충족 전에는 실제 merge하지 않습니다.
- 유효한 사람 승인은 PR 작성자·봇·삭제된 계정을 제외한 뒤, 현재 head의
  최신 `APPROVED` review와 GitHub API의 현재 저장소 권한
  (`admin`, `maintain`, `push`)을 모두 만족해야 합니다. `authorAssociation`만으로
  권한을 추정하지 않으며, collaborator가 아닌 reviewer의 404 응답은 승인으로
  세지 않습니다. 그 밖의 권한 조회 실패는 `needs-human`으로 중단합니다.
- `CHANGES_REQUESTED`는 review commit이 오래됐거나 새 커밋이 push됐다는 이유만으로
  해소하지 않습니다. 해당 reviewer가 현재 head를 `APPROVED`하거나 권한 있는 사용자가
  review를 명시적으로 dismiss해야 합니다. 후속 `COMMENTED`·`PENDING` 또는 stale head
  승인은 변경 요청을 해소하지 않습니다([GitHub review 정책](https://docs.github.com/en/pull-requests/how-tos/review-pull-requests/approving-a-pull-request-with-required-reviews)).
- 승인 job은 `required_status_checks.contexts`와 `checks[].context`의 합집합을
  branch protection의 기준으로 읽고, `gh pr checks --required`가 반환한 이름 집합과
  정확히 비교합니다. 빈·누락·추가 required check 또는 통과하지 않은 required check는
  모두 `needs-human`으로 중단합니다.
- branch protection의 `checks[].app_id`가 지정된 required check는 GitHub가 merge 시
  제공자도 강제합니다. 현재 `review` check는 Actions 앱(15368)에서 발행하며, trusted
  review workflow가 `checks:write` Actions 토큰으로 리뷰 대상 PR head SHA에 check run을
  만들거나 갱신합니다. `gh pr merge --auto`는 허용된 제공자의 check만 통과시킵니다
  ([branch protection API](https://docs.github.com/en/rest/branches/branch-protection)).
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

두 번째 응답에서 `required_approving_review_count`를 확인하고, 승인 수가 0보다 크면
stale review 설정도 확인합니다. 첫 번째 응답에서 required status checks와 branch
보호가 실제로 활성화되어 있는지 확인합니다. 확인 대상 저장소와
브랜치는 승인 job에 전달되는 `Repository`와 `BaseBranch`와 같아야
합니다.

## 변경 후 검증

1. 보호 설정 응답을 저장해 변경 전후를 비교합니다.
2. `scripts/complete-review-approval.ps1`의 승인 계약 테스트와
   `scripts/codex-branch-review-workflow-test.sh`를 실행합니다.
3. PR의 base/head SHA, 필수 CI check, 리뷰의 commit SHA를 다시 확인합니다.
4. PASS 4점 이상과 현재 head의 필수 check가 통과한 뒤 approval job이 Squash
   auto-merge를 큐에 넣는지 확인합니다. 사람 승인은 GitHub branch protection의 실제
   설정값이 0보다 큰 경우에만 추가로 요구됩니다.
