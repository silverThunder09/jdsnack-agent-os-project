---
name: review-loop
description: JDSnack 코드 리뷰 핸드오프 루프. 설정된 reviewer가 결정론 게이트(빌드/테스트/lint/diff 줄수/PR 계약)와 고정 5점 루브릭으로 판정한다. 현재 기본 reviewer는 Codex이며, Claude 결과 unavailable·누락·오류 시 Codex read-only reviewer를 실행한다. PASS 4점과 모든 current-head required checks 통과 시 Squash auto-merge를 큐에 넣는다.
---

# review-loop (설정된 reviewer = 게이트키퍼)

역할 분담: **Codex는 구현·테스트와 현재 기본 PR 리뷰**, **Claude는 기획·검증·PR 관리**를 담당합니다. reviewer 선택은 `scripts/review-policy.json`의 `primaryReviewer`를 따릅니다.
현재 primary reviewer는 Codex이므로 Claude 호출 없이 바로 읽기 전용 리뷰를 실행합니다. primary가 Claude이고 Claude가 unavailable이거나 구조화 결과를 반환하지 못하면 Codex read-only reviewer로 전환합니다. 유효한 Claude 판정은 Codex 결과로 덮어쓰지 않습니다. 어느 reviewer든 소스 코드를 수정하지 않습니다.
규칙 정본은 `.agent-os/`이며 여기서 재서술하지 않습니다.

## 0. 전제
- Codex가 에이전트 코딩을 끝내고 작업 브랜치에 **커밋·푸시**한 상태여야 함.
- 위험도·PR 흐름은 `.agent-os/operations/pr-automation-loop.md`를 따름.

## 1. 결정론 게이트 (LLM 호출 전 — 실패 시 리뷰 토큰 0)
Claude가 검증 목적으로 실행. 하나라도 실패하면 리뷰를 시작하지 않고 **2번 형식의 변경요청을 만들어 Codex에 넘김**:

1. **diff 줄수 한도** — 변경 1,000줄 초과면 PR 분할을 Codex에 요구하고 중단.
   `git diff --stat origin/main...HEAD` 합계(또는 `gh pr diff <N> | wc -l`) 확인.
2. **PR 계약** — `bash scripts/pr-contract-test.sh <N>`
3. **backend 변경 시** — `cd backend && ./gradlew test`
4. **frontend 변경 시** — `cd frontend && npm run lint && npm test`
5. 모두 통과해야 2단계로 진행. (게이트용 재실행은 Claude가 수행, 코드 수정은 하지 않음)

## 2. 리뷰 핸드오프 루프 (최대 3회)
`attempt = 1`로 시작. 각 회차:

1. **diff 추출** — 로컬이면 `git diff origin/main...HEAD`, PR이면 `gh pr diff <N>`.
2. **code-reviewer 서브에이전트 호출** — 입력은 *오직*:
   - 위 diff
   - 대상 spec의 `acceptance-criteria.md` / `test-scenarios.md` 경로
   - `attempt > 1`이면 **직전 회차 findings 중 미해결분(델타)만**
   - 전체 레포·`.agent-os` 전체·대화 전사를 넣지 말 것.
3. **점수 분기**:
   - `score ≥ 4` → **루프 종료(통과)**. 3단계로.
   - `score < 4` → **Claude는 수정하지 않는다.** code-reviewer의 findings를 그대로
     **Codex용 변경요청**으로 정리해 출력:
     ```
     → Codex 변경요청 (attempt N)
     score: N/5
     수정 항목(blocker/major 우선):
     - 파일:라인 — 무엇을 어떻게 고쳐야 하는가
     ```
     이후 **Codex가 같은 브랜치에서 수정·커밋·푸시**한다. 푸시 완료를 확인하면
     `attempt += 1` 후 1번(결정론 게이트 포함)부터 재리뷰. 재리뷰는 **델타만** 평가.
4. **시도 소진** — `attempt == 3`인데도 `score < 4`면 **루프 중단**. 자동 merge 금지:
   - 마지막 점수·미해결 findings를 사용자에게 에스컬레이션.
   - `pr-automation-loop.md` 기준 실패 Issue 생성 여부 판단.

## 3. 리뷰 결과 제출과 승인 job
리뷰 job은 구조화된 판정을 만들고, 승인 여부를 정해진 게이트에 맡깁니다. review job 자체에서는 PASS를 승인하거나 머지를 요청하지 않습니다.

1. 현재 PR 번호와 저장소를 확인하고, 이미 MERGED 상태이면 종료합니다.
2. 결과에 따라 review action을 한 번만 제출합니다.
   - PASS와 score 4 이상이면 review report를 artifact로 넘깁니다. 별도 approval job은 보고서 SHA, PR 계약, PR CI Gate, review check, 모든 branch-required check와 미해결 변경요청 부재를 다시 확인한 뒤 Squash auto-merge를 큐에 넣습니다.
   - REQUEST_CHANGES는 GitHub review로 한 번 제출합니다. 제출을 시도한 뒤 추가 comment review를 만들지 않습니다.
   - COMMENT, NEEDS_HUMAN, score 4 미만은 정식 comment review를 남기고 자동 병합을 중단합니다. 위험도는 라벨일 뿐 PASS 기준이나 승인 수를 바꾸지 않습니다.
   - 본문에는 review-loop, attempt, 점수, 결정, findings를 포함합니다.
3. score가 4 미만이거나 결정론 게이트가 실패하면 review job을 통과시키지 않습니다. approval job은 현재 실행의 review check도 GitHub가 SUCCESS/pass로 완료한 경우에만 인정하며, IN_PROGRESS/pending은 통과로 취급하지 않습니다.
4. 위험도 구간별 추가 사람 승인은 요구하지 않습니다. GitHub branch protection에 실제 승인 수가 설정되면 GitHub가 그대로 강제합니다.
5. approval job은 report와 최신 PR이 리뷰한 base/head SHA, Validate PR contract, PR CI Gate, PR head에 게시된 review check, 모든 branch-required check와 미해결 변경요청 부재를 확인한 뒤 Squash auto-merge를 큐에 넣습니다.
6. auto-merge 명령 성공만으로 머지 완료로 보고하지 않습니다.
   - gh pr view의 state가 MERGED이고 mergedAt이 있을 때만 완료로 보고합니다.
   - state가 OPEN이면 autoMergeRequest가 존재하는 경우에만 큐에 등록된 상태로 기록합니다.
   - 실패하거나 OPEN인데 autoMergeRequest가 없으면 needs-human으로 멈춥니다.

## 경계 규칙 (반드시 준수)
- **Claude는 소스 코드를 수정/커밋하지 않는다.** 수정의 주체는 항상 Codex.
- 리뷰어에 **diff + 합격기준 + 루브릭만** 전달. 레포 전체 주입 금지.
- 회차 간에는 **델타(미해결 findings)만** 넘기고 누적 전사 금지.
- 외부 리뷰 봇(Greptile 등)을 같이 쓰면 **이 로컬 루프와 둘 중 하나만** 매 회 실행.
- 리뷰어 출력은 `code-reviewer`의 구조화 형식만 허용. 산문 리뷰 금지.
