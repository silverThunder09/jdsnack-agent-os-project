# AI 리뷰 라우팅과 위험도 산식

## 위험도 점수

`scripts/review-risk.ps1`은 PR의 base/head diff를 읽어 아래 다섯 항목을 고정 합산합니다. 가중치와 경로 정규식은 `scripts/review-policy.json`을 정본으로 사용하며, 이 문서는 사람이 검토할 수 있는 설명입니다.

| 항목 | 점수 | 점수 조건 |
|---|---:|---|
| Security | 30 | `.github/**`, `.githooks/**`, 리뷰 fallback/운영 경계, 인증·보안·secret·credential·token·permission·환경변수 경로가 하나라도 변경됨 |
| API/DB/환경변수 | 20 | API·Controller·Repository·migration·schema, `application*.yml`, Compose·Dockerfile·`backends.json`, frontend service 경로가 하나라도 변경됨 |
| PR 크기·범위 | 0 / 8 / 15 | 100줄·5파일·1 논리 scope 이하는 0점, 300줄·10파일·2 논리 scope 이하는 8점, 그 외는 15점 |
| 테스트 공백 | 15 | backend·frontend·scripts·workflow·hook 소스가 변경됐는데 test 경로가 함께 변경되지 않음. `test`, `tests`, `*.test.*`, `*.spec.*`, `scripts/*-test.sh`, `scripts/*-test.ps1`를 테스트 경로로 인정 |
| 마이그레이션 | 20 | `db/migration`, `migrations`, `schema`, `flyway` 또는 `.sql` 경로가 변경됨 |

논리 scope는 `backend/src/main/controller`·`backend/src/main/resources`, `frontend/src/<영역>`, `.agent-os/<영역>`, `.github/<영역>`, `scripts`, `docs/<영역>`처럼 같은 최상위 디렉터리 안의 별도 변경 영역을 구분합니다. 총점은 0~100점이며 구간은 다음과 같습니다.

- `0~30`: `Light` — 사람 승인 1명 뒤 자동 병합 허용
- `31~60`: `Standard` — 사람 리뷰 필수, 자동 병합 차단
- `61~100`: `High-risk` — 추가 리뷰 2명과 저장소 소유자의 최신 head 명시 승인 필요

## 전문 리뷰 라벨

변경 경로는 아래 네 라벨로 라우팅됩니다. 하나의 PR에 여러 라벨을 붙일 수 있습니다.

- `Security`: `.github/**`, `.githooks/**`, review fallback·운영 경계, 인증·보안·secret·credential·token·permission·workflow 경로
- `Performance`: performance·benchmark·load·cache·async·worker·query·repository·sql 경로와 `frontend/src/components|hooks|pages|services/**`
- `Test Coverage`: backend·frontend·scripts·workflow·hook 또는 test 경로
- `Architecture`: `.agent-os/**`, `docs/architecture/**`, backend·frontend 소스, workflow·scripts·hooks, `AGENTS.md`·`CLAUDE.md`·`backends.json`

`scripts/pr-review-gate.sh`은 이 라우팅 결과를 출력하고, Claude 또는 Codex fallback 프롬프트에는 변경 경로·라벨·점수·구간을 함께 전달합니다.
경로 정규식과 라벨 규칙은 `review-risk.ps1`의 고정 digest로도 검증합니다. 규칙을 바꾸려면 정책 변경 자체를 별도 검토·커밋해야 하며, 임의의 PR이 점수나 라벨을 낮추도록 즉석에서 수정할 수 없습니다.

## 드라이런과 보호 규칙

초기 `scripts/review-policy.json`의 `dryRun`은 `true`입니다. 이 상태에서는 리뷰 실행, PASS 코멘트, 위험도·전문 라벨 게시만 수행하고 `gh pr merge`는 실행하지 않습니다. 승인 job은 dry-run 종료 전에 Codex fallback 자기검수 금지와 위험도별 사람 승인 수를 먼저 검증합니다.

`dryRun`을 해제한 뒤에도 승인 게이트가 점수 구간을 다시 확인합니다. `Light`는 승인 1명, `Standard`는 사람 리뷰 후 자동 병합 차단, `High-risk`는 최신 head의 승인 2명과 최신 head 이후 소유자 명시 확인을 요구합니다. 승인 job은 GitHub 보호 규칙의 실제 `required_approving_review_count`와 `dismiss_stale_reviews=true`를 확인해 정책 최소값과 큰 수를 적용합니다. 모든 위험도에서 현재 head SHA의 승인만 인정하며, 보호 규칙과 required check가 확인되지 않거나 stale review dismissal이 꺼져 있으면 `needs-human`으로 중단합니다.
