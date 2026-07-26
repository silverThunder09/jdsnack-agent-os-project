# AI 품질 평가와 prompt/model version 요구사항

## 출처

- `source_issue: 168` (GitHub Issue #168, `product-signal:analysis-data`)
- Issue 본문은 신뢰할 수 있는 트리거 신호로만 사용하고, 구체 범위는 기존 분석 이력 저장 경계(`.agent-os/archive/specs/2026-07-18-service-mvp/api-spec.md`, [ADR-020](../../adr/adr-020-analysis-input-record.md))와 충돌하지 않도록 이 문서에서 확정한다.

## 목표

분석 결과가 누적되기 시작한 시점에서, (1) 각 분석 이력이 어떤 AI 모델·프롬프트 버전으로 생성됐는지 추적하고, (2) 사용자가 해당 결과의 품질을 직접 평가(피드백)할 수 있게 한다. 두 흐름을 하나의 Feature Spec으로 묶되, 서로 다른 공개 경계를 가진 두 개의 수직 티켓으로 나눈다.

## 범위

### 포함

- 분석 이력(`diagnosis`, `match`) 생성 시 사용된 모델명·프롬프트 버전을 내부 저장소에 함께 기록 (T1)
- 로그인한 사용자가 본인 소유의 완료된 분석 이력에 좋아요/별로 형태의 품질 피드백과 선택적 코멘트를 남기고 다시 확인하는 흐름 (T2)
- 기존 `analysis_history`/`analysis_input_snapshot` 저장·조회·재시도·삭제 계약과의 호환성 유지

### 제외

- ATS 진단(`/api/ats/preview`)은 AI 호출 없이 서버 계산이므로 모델/프롬프트 버전 추적 대상에서 제외한다.
- 문장 첨삭·모의면접 preview(`sentence`, `interview`)는 현재 `analysis_history`에 저장되지 않으므로 이번 spec에서 저장 대상에 포함하지 않는다(기존 저장 범위 제약, [service-mvp requirements](../../archive/specs/2026-05-22-1650-resume-upload-fixture-mvp/requirements.md) 이후 변경 없음).
- prompt/model version을 공개 API·UI에 노출하는 것은 이번 spec 범위가 아니다(내부 메타데이터로만 유지).
- 모델/프롬프트 A-B 테스트, 자동 품질 채점(LLM-as-judge), 관리자 대시보드, 피드백 기반 자동 재학습은 포함하지 않는다.
- 기존 `POST/GET/DELETE /api/analysis-histories/**` 응답 스키마의 기존 필드 삭제·이름 변경은 하지 않는다(신규 필드 추가만 허용).

## 요구사항

### REQ-01 Prompt/Model Version 자동 기록 (내부 메타데이터)

분석 이력이 `diagnosis` 또는 `match` 결과를 저장할 때, 해당 결과를 생성한 AI 모델명과 프롬프트 버전을 함께 내부 저장소에 기록해야 한다. `diagnosis`와 `match`는 서로 다른 호출이므로 각각 독립적으로 기록한다.

### REQ-02 공개 경계: 내부 메타데이터와 사용자 기능 분리

모델명·프롬프트 버전은 공개 API 응답(`GET /api/analysis-histories/**`)과 프론트엔드 UI에 노출하지 않는다. 내부 저장소(DB)에만 남기며, 이후 별도 운영 도구가 필요하면 새 spec에서 다룬다.

### REQ-03 기존 저장·조회·재시도·삭제 흐름과의 호환

REQ-01의 컬럼 추가는 기존 `analysis_input_snapshot`/`analysis_history` 테이블 구조, 기존 API 응답 필드, 재시도(`POST .../retry`)·삭제(`DELETE ...`) 계약을 변경하지 않는다. 기존 필드는 그대로 유지된다.

### REQ-04 사용자 품질 피드백 제출

로그인한 사용자는 본인 소유의 `SUCCEEDED` 분석 이력에 대해 좋아요(`LIKE`)/별로(`DISLIKE`) 중 하나와 선택적 코멘트(최대 500자)로 구성된 품질 피드백을 제출할 수 있어야 한다. 이미 피드백을 남긴 이력에 다시 제출하면 기존 피드백을 갱신(upsert)한다.

### REQ-05 품질 피드백 조회

사용자는 분석 이력 상세 조회(`GET /api/analysis-histories/{historyId}`) 응답에서 본인이 남긴 피드백(있다면)을 함께 확인할 수 있어야 한다.

### REQ-06 피드백 소유권·상태 경계

피드백은 이력 소유자 본인만 제출·조회할 수 있다. 타인 소유 이력에 대한 피드백 제출·조회 시도는 기존 이력 조회와 동일하게 `ANALYSIS_HISTORY_NOT_FOUND` 계열로 처리해 존재 여부를 숨긴다. `RUNNING` 또는 `FAILED` 이력에는 피드백을 제출할 수 없다.

### REQ-07 재시도·삭제 시 피드백 처리

분석 이력을 삭제하면 연결된 피드백도 같은 트랜잭션 경계에서 함께 삭제된다. 재시도(`POST .../retry`)로 생성된 새 이력은 원본 이력의 피드백과 독립적인 새 피드백 슬롯을 가지며, 원본 이력의 피드백은 영향받지 않는다.
