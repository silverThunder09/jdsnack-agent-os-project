# JDSnack 후보 백로그

이 문서는 다음 기획 후보의 사람이 읽는 설명을 관리합니다. 실행 상태·우선순위·자동 승격 조건의 정본은 [`spec-queue.json`](spec-queue.json)입니다.

## 현재 active Feature Spec

- `jobkorea-jd-adapter`: [.agent-os/specs/2026-09-18-jobkorea-jd-adapter](../specs/2026-09-18-jobkorea-jd-adapter/plan.md). 기존 공통 JD fetch 경계에 JobKorea 출처만 추가하며, fixture 기준 검증으로 한정합니다.

## 최근 완료 Feature Spec

- 완료된 **AI 호출량·비용 제한**은 [archive](../archive/specs/2026-09-16-ai-usage-cost-limit/)로 이동했습니다(PR #205·#208).
- `analysis-progress-feedback`는 PR #194에서 완료되었고 [archive](../archive/specs/2026-09-15-analysis-progress-feedback/)로 이동했습니다.
- 분석 시작 후 결과 화면으로 먼저 전환되어 사용자가 전체 분석의 진행 여부를 알기 어려운 문제를 해결합니다.
- 백엔드 진행률 스트리밍·비동기 worker·가짜 퍼센트는 이번 범위에 포함하지 않고, 브라우저가 실제로 알고 있는 요청 상태만 표시합니다.
- 완료된 **AI 품질 평가와 prompt/model version**은 `.agent-os/archive/specs/2026-07-21-ai-quality-versioning/`로 이동했습니다. GitHub Issue #168(`product-signal:analysis-data`)에서 승격됐습니다.
- 이전 완료 Spec **분석 결과 리포트 내보내기**는 `.agent-os/archive/specs/2026-07-21-analysis-report-export/`에 있습니다.
- 이전 완료 Spec **ATS 점수·포맷 진단**은 `.agent-os/archive/specs/2026-07-20-ats-score-format/`에 있습니다.

## Post MVP 후보

| 후보 | 시작 조건 |
|---|---|
| RocketPunch JD adapter | JobKorea 범위와 효과를 검증한 뒤 |
| 비동기 analysis worker와 Redis | 동기 분석이 사용자 경험을 막는다고 확인된 뒤 |
| 결제 연동 — 토스페이먼츠 빌링 확정 | 요금제 도입 뒤 |
| 분석·수집 관측성과 장애 대응 | 운영 신호가 필요한 뒤 |
| EC2 실배포 (ADR-004) | OAuth 운영 redirect·결제가 고정 도메인+HTTPS를 전제하므로 MVP 운영 전환 전 |
| 요금제·사용량 제한 — 횟수 미터링 방식 확정 | 실사용자·비용 신호 확인 뒤 (기존 "AI 호출량·비용 제한" 후보와 통합 검토) |
| 결정론적 AI 품질 평가 (quality-v1) — [ADR-021](../adr/adr-021-deterministic-ai-quality-assessment.md) | 설계는 승인 완료(2026-07-24). 품질 점수 계산·`analysis_history` 저장·백엔드 응답 계약 구현은 `product-signal:analysis-quality` 신호 확인 뒤 |

결정 근거: [2026-07-16 spec backlog grill decisions](../archive/research/2026-07-16-spec-backlog-grill-decisions.md)

## 승격 규칙

- 승격 절차의 정본은 [doc-lifecycle.md](../standards/doc-lifecycle.md)와 [`spec-queue.json`](spec-queue.json)입니다.
- 자동 판정 가능한 시작조건을 충족한 첫 후보는 이벤트 기반 루프가 자동 승격합니다.
- 제품 신호가 필요한 후보는 해당 `product-signal:*` 라벨이 붙은 Issue가 생길 때까지 자동으로 추측하지 않습니다.
- 실행 명령 순서: `queue select → spec generate → spec validate → T1 dispatch → ticket advance → feature complete → queue select`.
