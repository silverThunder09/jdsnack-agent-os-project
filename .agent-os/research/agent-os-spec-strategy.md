# JDSnack AI 자동화 백로그의 Spec 전략

조사일: 2026-07-16
범위: `mattpocock/skills` 현재 소스, 공식 Agent OS v3 문서, OpenAI의 harness engineering 글, JDSnack 현재 문서

## 결론

JDSnack은 다음 4개 층을 유지하는 것이 가장 적합합니다.

1. **MVP**: 제품/로드맵상의 가치 검증 단위
2. **Feature spec(PRD 겸용)**: 한 기능의 사용자 문제, 요구사항, 계약, 수용 기준, 테스트, 범위, 결정사항을 보존하는 실행 계약
3. **Vertical-slice ticket**: 한 번에 구현할 작은 단위. 스키마부터 API·UI·테스트까지 좁고 완전한 사용자 경로를 포함
4. **Implementation run**: blocker가 해소된 ticket 하나를 구현하고 테스트·리뷰·검증한 뒤 다음 ticket으로 이동

따라서 **spec은 MVP나 ticket 자체가 아닙니다.** Spec은 상위 계약이고, MVP는 릴리스/가치 범위이며, ticket은 spec을 실행하는 수직 슬라이스입니다. JDSnack은 `active_specs` 1개와 짧은 후보 백로그를 분리하고, 선택된 Feature Spec 안에서 티켓을 순서대로 실행합니다. 현재의 `requirements → acceptance-criteria → test-scenarios → implementation → verification` 구조도 유지할 근거가 충분합니다.

## 1. `mattpocock/skills`의 실제 동작

아래는 README의 설명이 아니라 현재 저장소의 `SKILL.md`에 적힌 동작입니다.

| 단계 | 소스 사실 | JDSnack에 적용할 의미 |
|---|---|---|
| Grilling | [`grill-with-docs/SKILL.md`](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md)는 `/grilling`을 실행하고 `/domain-modeling`을 사용하며, 이름·설명상 ADR과 glossary도 함께 만든다. README는 이를 정렬, 공유 언어, 어려운 결정을 문서화하는 단계로 설명한다. | OAuth, 사용자/조직 소유권, JD source, 분석 상태처럼 용어와 선택지가 많은 기능의 사전 정리 단계로 사용한다. 단순 버그에는 강제하지 않는다. |
| Spec/PRD | [`to-spec/SKILL.md`](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-spec/SKILL.md)는 현재 대화와 코드베이스를 합성해 spec을 만들고, 요구사항을 다시 인터뷰하지 않는다. repo 탐색 후 테스트 seam을 먼저 스케치하고 사용자 확인을 받는다. 템플릿은 Problem Statement, Solution, 긴 User Stories, Implementation Decisions, Testing Decisions, Out of Scope, Further Notes다. 소스는 spec을 PRD라고도 부른다. | JDSnack의 spec은 이 역할을 `requirements`, `acceptance-criteria`, `test-scenarios`, API/UI 계약, `traceability`로 구체화하면 된다. 동일 기능에 PRD와 별도 실행 spec을 중복 생성하지 않는다. |
| Tickets | [`to-tickets/SKILL.md`](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-tickets/SKILL.md)는 spec/계획을 **tracer-bullet tickets**로 나눈다. 각 ticket은 스키마·API·UI·테스트를 관통하는 좁은 완전 경로이고, 단독 검증/데모 가능하며, 한 fresh context에 들어가야 한다. 각 ticket에 `Blocked by`를 선언하고, blocker가 끝난 frontier를 한 번에 하나씩 실행한다. 광범위 변경은 expand–contract로 예외 처리한다. | 여러 queued spec 안에서도 실제 구현 단위는 수직 ticket으로 둔다. DB만 먼저 만드는 수평 티켓은 꼭 필요한 사전 작업/expand 단계일 때만 허용한다. |
| Implementation | [`implement/SKILL.md`](https://github.com/mattpocock/skills/blob/main/skills/engineering/implement/SKILL.md)는 spec/ticket을 구현하고, 가능한 곳에서 TDD를 사전 합의한 seam에 적용하며, typecheck·단일 테스트를 자주 실행하고 마지막에 전체 테스트를 실행한다. 완료 후 code review를 사용하고 현재 branch에 commit한다. | 기능 테스트는 spec과 함께 설계하고, 외부 OAuth·Gemini·DB를 실호출하지 않는 fake/stub 경계를 먼저 고정한다. |
| Review | [`code-review/SKILL.md`](https://github.com/mattpocock/skills/blob/main/skills/engineering/code-review/SKILL.md)는 고정 기준점부터의 diff를 `Standards`와 `Spec` 두 축으로 검토한다. spec 원천과 standards 원천을 찾고, 두 리뷰를 분리해 실행한다. spec이 없으면 spec 축을 생략한다고 보고한다. | JDSnack의 문서/표준 준수 검토와 REQ·AC·TC 구현 검토를 분리하는 현재 review gate와 일치한다. |

README도 이 순서를 `grill-with-docs → to-spec → to-tickets → implement → code-review`로 나열하고, `to-tickets`를 dependency edge와 함께 쓰는 vertical slice 도구로 명시합니다: [`skills/README.md`](https://github.com/mattpocock/skills/blob/main/README.md#engineering).

**한계:** `to-spec`은 설정된 issue tracker에 spec을 publish하는 흐름을 전제로 합니다. JDSnack은 repo-local `.agent-os/specs/`를 system of record로 삼으므로, 절차와 ticket shape만 차용하고 저장 위치·티켓 전진 규칙은 JDSnack 정책을 우선해야 합니다.

## 2. Agent OS와 harness에서 확인되는 패턴

### Agent OS v3

- 공식 [Shape Spec 문서](https://buildermethods.com/agent-os/shape-spec)는 **중요한 작업은 plan mode에서 지속 spec으로 저장**하고, 빠른 작업은 지속 문서 없이 plan mode를 사용하라고 구분합니다.
- 저장되는 spec은 `plan.md`, `shape.md`, `references.md`, `standards.md`, 선택적 `visuals/`로 구성됩니다. 목적은 나중에 무엇을 왜 만들었는지 복원하는 것입니다.
- [v3 migration 문서](https://buildermethods.com/agent-os/migration)는 spec 구조는 유지하되 spec 작성·task breakdown·구현 orchestration을 frontier agent의 plan mode와 기본 기능에 맡기고, Agent OS의 중심을 standards와 context 주입으로 이동했다고 설명합니다.
- [File Structure 문서](https://buildermethods.com/agent-os/file-structure)는 product docs(`mission`, `roadmap`, `tech-stack`), standards/index, specs를 별도 층으로 둡니다.

**해석/권고:** Agent OS는 JDSnack의 `mission/roadmap/tech-stack → standards → feature spec` 분리를 지지합니다. JDSnack은 상세 pending Spec 큐 대신 active Feature Spec 하나와 후보 백로그를 분리하고, 자동화 범위는 Feature Spec 내부의 티켓 전진으로 제한합니다.

### Agent-first harness

OpenAI의 [Harness engineering](https://openai.com/index/harness-engineering/) 글은 다음을 소스 사실로 제시합니다.

- 큰 목표를 design, code, review, test 같은 작은 building block으로 depth-first 분해한다.
- 짧은 `AGENTS.md`는 백과사전이 아니라 지도이고, repo-local `docs/`가 system of record가 된다.
- active/completed execution plan과 decision log를 version control에 둔다.
- progressive disclosure로 처음에는 작은 진입점만 읽고 필요한 문서로 내려간다.
- 문서만 믿지 않고 linter, CI, structural test로 경계와 신선도를 기계적으로 검증한다.
- strict boundary와 예측 가능한 계층을 강제하되, 구현 표현 자체는 과도하게 고정하지 않는다.

**JDSnack 권고:** 현재의 짧은 `AGENTS.md`, `.agent-os` 문서 지도, REQ→AC→TC traceability, CI/review gate는 이 패턴과 일치합니다. OAuth·DB·외부 JD fetch·Gemini처럼 위험도가 높은 작업은 spec 안에 `위험도 / 외부 의존성 / blocker / migration·rollback / secret 처리 / 검증 명령`을 명시하고, 반복되는 누락은 문서가 아니라 lint 또는 CI 규칙으로 승격하는 것이 좋습니다.

## 3. MVP·Vertical Slice·PRD·Ticket의 역할 구분

| 개념 | 적절한 질문 | JDSnack에서의 권장 사용 |
|---|---|---|
| MVP | “사용자 가치의 어느 범위를 이번 단계에서 검증하는가?” | roadmap의 Phase/기능 묶음. 예: JD 입력 설계 MVP, 사람인 링크 수집 안정화 MVP. 구현 단위로 직접 실행하지 않는다. |
| Feature spec / PRD | “무엇을, 왜, 어떤 계약과 검증으로 완성으로 볼 것인가?” | 한 사용자 가치 또는 밀접한 변경 묶음. requirements·AC·TC·API/UI·traceability·ADR 링크·범위 밖을 포함한다. |
| Vertical-slice ticket | “이번 context에서 사용자가 확인 가능한 어떤 완전한 경로를 만들 것인가?” | schema→backend→frontend→external boundary→test를 필요한 만큼 관통한다. 각 ticket은 acceptance와 blocker를 가진다. |
| Ticket | “누가 지금 무엇을 집어 구현할 수 있는가?” | tracker 또는 spec 하위 실행 단위. JDSnack은 `ready / blocked / done`과 선행 ticket을 명확히 기록한다. |

**핵심 판단:** “MVP spec”이라는 표현은 제품 범위를 설명할 때만 사용하고, backlog 실행에서는 `feature spec → vertical tickets`로 번역합니다. 특히 “OAuth 전체”, “다중 source ingestion 전체”, “DB 개편 전체” 같은 이름은 너무 큽니다. 사용자에게 보이는 첫 완전 경로를 기준으로 spec을 자르고, 각 spec 안에서 source별·흐름별 ticket을 만듭니다.

## 4. JDSnack에 맞춘 적용안

### OAuth와 DB

**권고:** OAuth 로그인 자체를 끝내는 데서 멈추지 말고, “로그인한 사용자가 인증된 API를 호출하고 사용자 소유 JD를 저장/조회한다”처럼 사용자 검증이 가능한 feature spec으로 정의합니다. Provider callback, session/token 경계, 사용자 식별자 저장, migration, 권한 오류, fake provider 테스트를 계약에 넣습니다. OAuth·DB·secret은 High-risk로 분류하고, 실제 provider와 운영 secret 없이도 통과하는 테스트 seam을 먼저 둡니다.

DB migration이 광범위한 기존 호출자를 깨뜨리는 경우에는 `to-tickets`의 expand–migrate–contract 순서를 적용합니다. 수평 migration을 억지로 하나의 vertical ticket으로 포장하지 말고, 각 단계가 CI를 유지하는지와 최종 contract를 별도 검증합니다.

### 다중 source JD ingestion

**권고:** “JD ingestion platform” 하나를 거대한 spec으로 만들지 않습니다. 첫 spec은 사용자가 특정 source의 JD를 가져와 저장/분석할 수 있는 한 경로로 제한하고, ticket은 source adapter·URL/SSRF 검증·본문 추출·실패 응답·저장/분석·테스트를 한 경로로 연결합니다. 다음 source는 동일한 공통 계약을 재사용하는 별도 vertical ticket 또는 별도 spec으로 둡니다.

공통 abstraction은 첫 source의 실제 경계가 드러난 뒤 최소 형태로 만들고, `sourceSite`, `fetchMode`, provenance, timeout/size/allowlist, graceful fallback을 계약에 남깁니다. 사람인 이미지 OCR처럼 외부 API와 보안 경계가 있는 기능은 현재 active spec의 REQ/AC/TC 방식처럼 “정상 경로”, “실패 시 기존 오류”, “외부 호출 없음 테스트”를 모두 수용 기준으로 고정합니다.

### 큐와 실행

현재 [`index.yml`](../standards/index.yml)과 [`doc-lifecycle.md`](../standards/doc-lifecycle.md)의 정책을 기준으로 다음을 지킵니다.

- `active_specs`는 항상 정확히 1개만 둔다.
- `pending_specs`는 구현 가능한 순서와 선행 조건을 가진 spec 목록으로 둔다.
- 현재 spec의 필수 DB·Redis·외부 서비스가 없으면 일부 테스트 통과를 완료로 간주하지 않고 전체 spec을 blocked로 둔다.
- spec 완료·archive·다음 active 승격은 테스트·traceability·review gate 통과 뒤 원자적으로 수행한다.
- 다음 spec은 앞 spec의 계약과 ADR을 읽을 수 있어야 하며, 이전 대화나 사람의 기억에 의존하지 않는다.

## 최종 권장 템플릿

JDSnack의 각 queued spec은 현재 문서 세트를 유지하되 다음 정보를 명시하면 충분합니다.

```text
spec = 사용자 가치 + 범위 + REQ + AC + TC + API/UI 계약 + traceability
     + 적용 standards + 관련 technical ADR + 위험도/외부 의존성/rollback

ticket = 한 사용자 경로를 끝까지 통과하는 vertical slice
        + acceptance + blocked-by + 검증 명령 + 완료 증거

MVP = 여러 spec을 묶는 제품/로드맵 레이블
```

즉, **PRD를 따로 만들지 말고 feature spec이 PRD 역할을 겸하게 하며, spec을 실행 가능한 vertical ticket들로 쪼개고, MVP는 roadmap에서만 사용**하는 결론입니다. 이는 `mattpocock/skills`의 현재 source behavior와 Agent OS/harness의 “작게 실행하고, repo에 남기고, 기계적으로 검증한다”는 공통 방향을 JDSnack의 OAuth·DB·다중 source·순차 큐 요구에 맞춘 형태입니다.

## Sources

- [mattpocock/skills README](https://github.com/mattpocock/skills/blob/main/README.md)
- [`grill-with-docs` source](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md)
- [`to-spec` source](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-spec/SKILL.md)
- [`to-tickets` source](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-tickets/SKILL.md)
- [`implement` source](https://github.com/mattpocock/skills/blob/main/skills/engineering/implement/SKILL.md)
- [`code-review` source](https://github.com/mattpocock/skills/blob/main/skills/engineering/code-review/SKILL.md)
- [Agent OS: Shape Spec](https://buildermethods.com/agent-os/shape-spec)
- [Agent OS: What's New in v3](https://buildermethods.com/agent-os/migration)
- [Agent OS: File Structure](https://buildermethods.com/agent-os/file-structure)
- [OpenAI: Harness engineering](https://openai.com/index/harness-engineering/)
- [JDSnack standards index](../standards/index.yml), [document lifecycle](../standards/doc-lifecycle.md), [Codex harness](../standards/codex-harness.md), [current active spec](../specs/2026-07-18-service-mvp/)
