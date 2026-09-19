# 리뷰 백엔드 폴백

## 목적

Claude 리뷰 서비스가 인증·구독·쿼터·자격 증명 장애로 실행되지 않을 때에도, PR 검증을 조용히 통과시키지 않고 Codex 읽기 전용 리뷰어에게 위임합니다.

## 전환 순서

1. codex-branch-review.yml이 먼저 Claude review-loop를 한 번 실행합니다.
2. Claude가 정상 종료하면 Claude의 판정만 사용합니다.
3. Claude 프로세스가 구독·인증·쿼터·자격 증명·실행 파일 unavailable 오류로 실패하면 scripts/review-backend-fallback.ps1이 Codex fallback을 호출합니다.
4. Codex fallback은 정확히 checkout된 PR head의 `origin/main...HEAD` diff와 명시된 acceptance/test 기준만 읽고, 파일을 수정·커밋·푸시하지 않은 채 같은 5점 루브릭으로 구조화된 결과를 반환합니다. 리뷰 모델은 루트 `backends.json`의 `workers.codex.review-fallback.model`을 사용합니다.
5. Codex 결과가 PASS이고 4점 이상이며 위험도가 Light 또는 Standard이고, 현재 review job을 제외한 required check가 모두 통과하면 runner의 GitHub CLI가 정식 review와 auto-merge를 요청합니다.
6. High-risk, 점수 4점 미만, COMMENT, REQUEST_CHANGES, 결과 형식 불명확, Codex 실행 불가 또는 GitHub review 실패는 needs-human으로 기록하고 머지를 막습니다.

## 장애 경계

- Claude의 코드상 리뷰 반려와 Claude 서비스 unavailable은 구분합니다. 리뷰 내용의 실패는 Codex fallback으로 바꾸지 않습니다.
- Codex fallback은 원래 PR의 acceptance criteria, 테스트, 보안, 범위 게이트를 낮추지 않습니다.
- 수동 `workflow_dispatch`도 PR head ref를 checkout한 뒤 review base를 fetch합니다. 다른 브랜치나 기본 브랜치를 잘못 리뷰하지 않습니다.
- fallback이 성공했다는 것은 reviewer backend가 바뀌었다는 뜻이지, 테스트·CI·보호 규칙을 생략했다는 뜻이 아닙니다.
- --admin이나 보호 규칙 제거로 fallback을 성공 처리하지 않습니다.

## 기록

fallback 실행 시 PR review report와 GitHub Actions step summary에 아래를 남깁니다.

- reviewer backend: codex-fallback
- Claude failure reason
- Codex score / decision / risk
- needs-human이면 재개에 필요한 조치
