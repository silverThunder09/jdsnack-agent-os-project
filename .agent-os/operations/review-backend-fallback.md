# 리뷰 백엔드 폴백

## 목적

Claude 리뷰 서비스가 인증·구독·쿼터·자격 증명 장애로 실행되지 않을 때 Codex를 읽기 전용 리뷰어로 사용합니다. 폴백은 자동 승인의 조건을 낮추지 않습니다.

## 전환 및 승인 순서

1. `PR CI Router`가 성공한 뒤 `codex-branch-review.yml`이 trusted base에서 Claude review-loop를 실행합니다. CI가 실패하면 리뷰는 시작하지 않고 PR Feedback Detector가 먼저 Codex 수정 작업을 디스패치합니다. Claude는 trusted base에서 만든 PR diff와 검토 기준만 restricted/plan 모드로 읽습니다. 저장소 소유자가 auto-merge를 켜면 `auto_merge_enabled` 이벤트도 같은 trusted workflow를 깨웁니다.
2. Claude가 정상 종료하면 그 판정을 사용합니다. 코드상 리뷰 반려와 서비스 unavailable은 구분하며, 리뷰 반려를 Codex fallback으로 바꾸지 않습니다.
3. Claude가 인증·구독·쿼터·자격 증명·실행 파일 unavailable 오류로 실패하면 scripts/review-backend-fallback.ps1이 Codex를 호출합니다.
4. Codex 입력은 PR diff와 검토 기준뿐입니다. Codex는 저장소 checkout 바깥의 빈 임시 작업공간에서 실행하며, 상위 경로의 AGENTS.md 존재 여부를 먼저 확인합니다. shell, app, plugin, remote plugin, multi-agent, memories, hooks, goals, browser/computer, code mode, skill 검색·설치를 끄고 web 검색을 비활성화합니다. 사용자 설정을 무시하고 저장소 경로와 GitHub 토큰·PR 환경 변수도 Codex 프로세스에 전달하지 않습니다. 리뷰 모델은 루트 backends.json의 workers.codex.review-fallback.model을 사용합니다.
5. 리뷰 job은 PASS, 4점 이상, 통과한 Validate PR contract와 PR CI Gate를 확인한 뒤 성공합니다. High-risk는 저장소 소유자가 최신 head 커밋 이후 Squash auto-merge를 켠 경우에만 사람 확인으로 인정합니다. `NEEDS_HUMAN`은 소유자 확인이 있어도 항상 중단합니다. 결정론적으로 선택하지 않은 backend/frontend 체크의 `skipping`은 PR CI Gate가 통과했을 때 허용합니다.
6. 별도 approval job은 성공한 리뷰 job에 의존합니다. 리뷰 보고서의 점수·위험도·base/head SHA, 현재 열린 PR의 저장소와 SHA, Validate PR contract, PR CI Gate, review check, 모든 branch-required check를 다시 확인합니다. High-risk는 소유자 확인을 다시 검증합니다. 확인 후 별도 GitHub `APPROVE` 리뷰를 만들지 않고 Squash auto-merge를 큐에 넣습니다. 저장소의 필수 승인 리뷰 수는 0이며, `review`는 GitHub Actions 상태 체크입니다.

## 사람 확인이 필요한 경우

- High-risk 판정은 저장소 소유자의 명시적 확인이 필요합니다. 소유자는 최신 head 커밋 이후 해당 PR의 Squash auto-merge를 직접 켭니다. 확인은 현재 head SHA에만 적용되며, 새 커밋 뒤에는 다시 켜야 합니다.
- 점수 4점 미만, COMMENT, REQUEST_CHANGES, NEEDS_HUMAN, 결과 형식 불명확, Codex 실행 불가, 현재 PR SHA 변경, 실패·누락 상태의 필수 check, GitHub 작업 실패는 needs-human으로 중단합니다. High-risk라는 이유만으로 `NEEDS_HUMAN`을 반환하지 않습니다. 경로 기반 라우터가 제외한 체크의 `skipping`은 PR CI Gate가 성공했을 때 통과로 인정합니다.
- REQUEST_CHANGES는 GitHub review로 한 번만 제출합니다. 제출 시도 뒤 추가 comment review를 만들지 않습니다.
- findings는 여러 줄과 전체 길이를 유지해 review 본문에 포함합니다. 필드 추출 과정에서 공백을 합치거나 내용을 잘라내지 않습니다.

## 장애 경계

- `pull_request_target`은 trusted base의 workflow만 사용합니다. 리뷰 workflow를 바꾸는 PR은 새 `review` 상태 체크를 스스로 만들 수 없으므로 첫 적용은 저장소 소유자가 한 번 bootstrap해야 합니다. 이 저장소는 필수 GitHub 승인 리뷰 수가 0이므로 다른 사람 리뷰는 필요하지 않습니다. 기본 브랜치에 trusted workflow가 올라간 뒤에는 PR 변경 및 소유자의 `auto_merge_enabled` 이벤트가 리뷰를 다시 실행합니다.
- 수동 workflow_dispatch는 GitHub API로 열린 PR의 base/head 저장소와 SHA를 확인한 뒤 같은 저장소 커밋만 fetch합니다. PR head의 파일·workflow·스크립트를 checkout하거나 실행하지 않습니다.
- workflow, skill, fallback/approval script는 trusted base에서 가져옵니다. PR diff와 PR 본문은 지시문이 아닌 untrusted evidence로 취급합니다.
- Codex fallback은 acceptance criteria, 테스트, 보안, 범위 게이트를 낮추지 않습니다.
- --admin이나 보호 규칙 제거로 fallback을 성공 처리하지 않습니다.

## 기록

리뷰 보고서와 GitHub Actions summary에는 reviewer backend, Claude 장애 사유, Codex score/decision/risk, 리뷰 대상 base/head SHA, findings, summary를 남깁니다. 성공한 리뷰 보고서는 현재 workflow run에만 연결된 artifact로 approval job에 전달합니다.
