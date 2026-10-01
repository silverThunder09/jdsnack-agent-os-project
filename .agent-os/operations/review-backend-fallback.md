# 리뷰 백엔드 폴백

## 목적

Claude 리뷰 서비스가 구독 비활성화, 인증·쿼터·자격 증명 장애로 실행되지 않거나 유효한 구조화 리뷰를 반환하지 못할 때 Codex를 읽기 전용 리뷰어로 사용합니다. 폴백은 자동 승인의 조건을 낮추지 않습니다.

## 전환 및 승인 순서

1. `PR CI Router`가 성공한 뒤 `codex-branch-review.yml`이 trusted base에서 Claude review-loop를 실행합니다. CI가 실패하면 리뷰는 시작하지 않고 PR Feedback Detector가 먼저 Codex 수정 작업을 디스패치합니다. Claude는 trusted base에서 만든 PR diff와 검토 기준만 restricted/plan 모드로 읽습니다. 저장소 소유자가 auto-merge를 켜면 `auto_merge_enabled` 이벤트도 같은 trusted workflow를 깨웁니다.
2. Claude가 유효한 구조화 리뷰를 반환하면 그 판정을 사용합니다. `REQUEST_CHANGES`, `COMMENT`, `NEEDS_HUMAN`, 점수 미달도 그대로 존중하며 Codex fallback으로 바꾸지 않습니다.
3. Claude 실행이 실패하거나 `decision`, `score`, `risk`, `findings`, `review_summary` 중 하나라도 빠진 구조화 리뷰를 반환하지 못하면 Codex가 PR diff와 검토 기준만으로 리뷰를 이어받습니다. 종료 코드가 0이 아니더라도 이 필드를 모두 갖춘 Claude 결정은 그대로 권위 있게 처리합니다. 구독·인증·쿼터 같은 장애 신호는 fallback 사유로 기록합니다.
4. Codex 입력은 PR diff와 검토 기준뿐입니다. Codex는 저장소 checkout 바깥의 빈 임시 작업공간에서 실행하며, 상위 경로의 AGENTS.md 존재 여부를 먼저 확인합니다. shell, app, plugin, remote plugin, multi-agent, memories, hooks, goals, browser/computer, code mode, skill 검색·설치를 끄고 web 검색을 비활성화합니다. 사용자 설정을 무시하고 저장소 경로와 GitHub 토큰·PR 환경 변수도 Codex 프로세스에 전달하지 않습니다. 요청된 논리 모델은 루트 `backends.json`의 `workers.codex.review-fallback.model`에 `gpt-Luna MAX`로 기록하며, 현재 ChatGPT Codex 런타임에서 지원되는 `runtimeModel`(`gpt-6-luna`)로 실행합니다.
5. 리뷰 job은 PASS, 4점 이상, 통과한 Validate PR contract와 PR CI Gate를 확인한 뒤 성공합니다. `scripts/review-risk.ps1`이 계산한 위험도 점수·구간과 Security·Performance·Test Coverage·Architecture 라벨을 프롬프트에 전달하고, 결과는 같은 head SHA에 대해 PR 코멘트와 라벨로 공개합니다. `NEEDS_HUMAN`은 항상 중단합니다. 결정론적으로 선택하지 않은 backend/frontend 체크의 `skipping`은 PR CI Gate가 통과했을 때 허용합니다.
6. 별도 approval job은 성공한 리뷰 job에 의존합니다. 리뷰 보고서의 점수·위험도·위험도 점수·base/head SHA, 현재 열린 PR의 저장소와 SHA, Validate PR contract, PR CI Gate, review check, 모든 branch-required check를 다시 확인합니다. 초기 `scripts/review-policy.json`의 `dryRun=true`에서는 리뷰·코멘트·라벨만 수행하고 `gh pr merge`를 호출하지 않습니다. 드라이런 해제 뒤 `Light`는 승인 1명, `Standard`는 사람 리뷰 후 자동 병합 차단, `High-risk`는 승인 2명과 최신 head 이후 소유자 명시 확인을 적용합니다.

## 사람 확인이 필요한 경우

- High-risk 판정은 저장소 소유자의 명시적 확인과 추가 사람 승인 2명이 필요합니다. 소유자는 최신 head 커밋 이후 해당 PR의 Squash auto-merge를 직접 켭니다. 확인은 현재 head SHA에만 적용되며, 새 커밋 뒤에는 다시 켜야 합니다.
- 점수 4점 미만, COMMENT, REQUEST_CHANGES, NEEDS_HUMAN, Codex 출력 형식 오류, Codex 실행 불가, 현재 PR SHA 변경, 실패·누락 상태의 필수 check, GitHub 작업 실패는 needs-human으로 중단합니다. High-risk라는 이유만으로 `NEEDS_HUMAN`을 반환하지 않습니다. 경로 기반 라우터가 제외한 체크의 `skipping`은 PR CI Gate가 성공했을 때 통과로 인정합니다.
- REQUEST_CHANGES는 GitHub review로 한 번만 제출합니다. 제출 시도 뒤 추가 comment review를 만들지 않습니다.
- findings는 여러 줄과 전체 길이를 유지해 review 본문에 포함합니다. 필드 추출 과정에서 공백을 합치거나 내용을 잘라내지 않습니다.

## 장애 경계

- `pull_request_target`은 trusted base의 workflow만 사용합니다. 리뷰 workflow를 바꾸는 PR은 새 `review` 상태 체크를 스스로 만들 수 없으므로 첫 적용은 저장소 소유자가 한 번 bootstrap해야 합니다. 기본 브랜치 보호 규칙은 사람 승인 1명과 `review`·`PR CI Gate`·`Validate PR contract`를 기본 required check로 유지하고, 승인 job이 위험도 구간에 따라 추가 승인을 결정론적으로 확인합니다. 기본 브랜치에 trusted workflow가 올라간 뒤에는 PR 변경 및 소유자의 `auto_merge_enabled` 이벤트가 리뷰를 다시 실행합니다.
- 수동 workflow_dispatch는 GitHub API로 열린 PR의 base/head 저장소와 SHA를 확인한 뒤 같은 저장소 커밋만 fetch합니다. PR head의 파일·workflow·스크립트를 checkout하거나 실행하지 않습니다.
- workflow, skill, fallback/approval script는 trusted base에서 가져옵니다. PR diff와 PR 본문은 지시문이 아닌 untrusted evidence로 취급합니다.
- Codex fallback은 acceptance criteria, 테스트, 보안, 범위 게이트를 낮추지 않습니다.
- --admin이나 보호 규칙 제거로 fallback을 성공 처리하지 않습니다.

## 기록

리뷰 보고서와 GitHub Actions summary에는 reviewer backend, Claude 장애 또는 유효한 리뷰를 반환하지 못한 사유, score/decision/risk, 고정 위험도 score·components·merge policy, 리뷰 라벨, 리뷰 대상 base/head SHA, findings, summary를 남깁니다. PASS 결과는 같은 정보를 담은 PR 코멘트로도 공개하고, 위험도·전문 라벨을 PR에 붙입니다. 성공한 리뷰 보고서는 현재 workflow run에만 연결된 artifact로 approval job에 전달합니다.
