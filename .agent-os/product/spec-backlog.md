# JDSnack 후보 백로그

이 문서는 다음 기획 후보의 사람이 읽는 설명을 관리합니다. 실행 상태·우선순위·자동 승격 조건의 정본은 [`spec-queue.json`](spec-queue.json)입니다.

## 현재 Feature Spec

- 현재 active Spec은 없습니다. 다음 후보는 제품 신호 `product-signal:analysis-data`가 붙은 Issue가 생성될 때 승격합니다.
- 완료된 **분석 결과 리포트 내보내기**는 `.agent-os/archive/specs/2026-07-21-analysis-report-export/`로 이동했습니다.
- 이전 완료 Spec **ATS 점수·포맷 진단**은 `.agent-os/archive/specs/2026-07-20-ats-score-format/`에 있습니다.

## Post MVP 후보

| 후보 | 시작 조건 |
|---|---|
| AI 품질 평가와 prompt/model version | 실제 분석 결과를 누적한 뒤 |
| AI 호출량·비용 제한 | 호출량 또는 비용 경계가 필요해진 뒤 |
| JobKorea JD adapter | 사람인 외 수집 수요가 확인된 뒤 |
| RocketPunch JD adapter | JobKorea 범위와 효과를 검증한 뒤 |
| 비동기 analysis worker와 Redis | 동기 분석이 사용자 경험을 막는다고 확인된 뒤 |
| 결제 연동 — 토스페이먼츠 빌링 확정 | 요금제 도입 뒤 |
| 분석·수집 관측성과 장애 대응 | 운영 신호가 필요한 뒤 |
| EC2 실배포 (ADR-004) | OAuth 운영 redirect·결제가 고정 도메인+HTTPS를 전제하므로 MVP 운영 전환 전 |
| 요금제·사용량 제한 — 횟수 미터링 방식 확정 | 실사용자·비용 신호 확인 뒤 (기존 "AI 호출량·비용 제한" 후보와 통합 검토) |

결정 근거: [2026-07-16 spec backlog grill decisions](../archive/research/2026-07-16-spec-backlog-grill-decisions.md)

## 승격 규칙

- 승격 절차의 정본은 [doc-lifecycle.md](../standards/doc-lifecycle.md)와 [`spec-queue.json`](spec-queue.json)입니다.
- 자동 판정 가능한 시작조건을 충족한 첫 후보는 이벤트 기반 루프가 자동 승격합니다.
- 제품 신호가 필요한 후보는 해당 `product-signal:*` 라벨이 붙은 Issue가 생길 때까지 자동으로 추측하지 않습니다.
- 실행 명령 순서: `queue select → spec generate → spec validate → T1 dispatch → ticket advance → feature complete → queue select`.
