# AI 품질 평가와 prompt/model version 구현 계획

## 상태

- Feature Spec 상태: `completed`
- 구현 상태: `completed`

## 내부 수직 티켓

### T1. Prompt/Model Version 내부 기록

- 범위: `analysis_history` 스키마에 `diagnosis_model_name`, `diagnosis_prompt_version`, `match_model_name`, `match_prompt_version` 내부 컬럼 추가, `AnalysisHistory` record·repository INSERT/rowMapper 갱신, `GeminiDiagnosisProvider`/`GeminiMatchPreviewProvider` 결과 저장 시 모델명·프롬프트 버전 함께 전달, 공개 응답 DTO에는 매핑하지 않음, 기능 테스트
- 의존성: 없음 (현재 `analysis_history`/`analysis_input_snapshot` 스키마, `.agent-os/adr/adr-019-postgresql-service-storage.md`, `.agent-os/adr/adr-020-analysis-input-record.md`)
- 완료 조건: AC-01~AC-03, TC-01~TC-04
- 상태: `completed`
- 완료 근거: `AnalysisHistoryControllerTest`로 생성·파일 생성·목록·상세·재시도 응답 비노출과 내부 저장을, `AnalysisHistoryPartialFailureTest`·`AnalysisHistoryPartialFailureMetadataTest`로 fixture/AI_LOCAL 매칭 실패 시 진단 메타데이터만 보존되는 경계를, `GeminiDiagnosisProviderMetadataTest`·`GeminiMatchPreviewProviderTest`로 실제 provider 모델·프롬프트 버전 전달을, `AnalysisExecutionVersionTest`로 null·blank 메타데이터 경계를 검증했다. `./gradlew test bootJar --no-daemon`, Docs Harness, AI-readiness, Compose 재빌드·health 검증을 통과했다.
- 구현 예상 위치: `backend/src/main/resources/schema.sql`, `backend/src/main/java/com/jdsnack/analysis/{AnalysisHistory,AnalysisExecutionVersion,AnalysisHistoryRepository,AnalysisHistoryService}.java`, `backend/src/main/java/com/jdsnack/diagnose/{DiagnoseService,*DiagnosisProvider}.java`, `backend/src/main/java/com/jdsnack/match/{MatchPreviewService,GeminiMatchPreviewProvider}.java`

### T2. 사용자 품질 피드백

- 범위: `analysis_feedback` 테이블 신설(이력당 사용자 1건, upsert), `POST /api/analysis-histories/{historyId}/feedback`, `GET /api/analysis-histories/{historyId}` 응답에 `feedback` 필드 추가, 이력 삭제 시 피드백 연쇄 삭제, `AnalysisHistoryView` 피드백 위젯, 기능 테스트
- 의존성: T1 완료(같은 Feature Spec 내 순차 진행), 기존 `GET/DELETE/retry /api/analysis-histories/**` 소유권·상태 경계 재사용
- 완료 조건: AC-04~AC-07, TC-05~TC-13
- 상태: `completed`
- 완료 근거: `AnalysisFeedbackControllerTest`(10건)로 최초 제출(TC-05), upsert 갱신 시 레코드 1건 유지(TC-06), 코멘트 501자 거부·500자 경계 허용·rating 누락/오값 거부(TC-07), 상세 응답의 `feedback` 포함과 미제출 시 `null`(TC-08), 타인 소유 제출·조회 404(TC-09), `RUNNING`/`FAILED` 제출 409(TC-10), 이력 삭제 시 피드백 연쇄 삭제(TC-11), 재시도 이력의 피드백 미상속·원본 유지(TC-12)를 검증했다. `AnalysisHistoryView.test.tsx`에 피드백 위젯 6건(TC-13)을 추가해 성공 이력 노출, 미선택 시 제출 비활성, 제출 위임과 저장 표시, 기존 피드백 프리필, `RUNNING`/`FAILED` 미노출, 서버 오류 메시지 표시를 검증했다. `./gradlew test`, `npm run lint && npm test && npm run build`, Docs Harness, AI-readiness를 통과했다.
- 백엔드 배정: `claude-fallback` (Codex outage로 `.agent-os/operations/worker-backends.md` 폴백 규칙 적용, 사용자 승인 2026-08-02)
- 구현 예상 위치: `backend/src/main/resources/schema.sql`, `backend/src/main/java/com/jdsnack/analysis/**`, `frontend/src/features/analysis/AnalysisHistoryView.tsx`, `frontend/src/services/**`

## 공통 검증

- 백엔드: `cd backend && ./gradlew test`
- 프론트: `cd frontend && npm run lint && npm test && npm run build`
- 문서: active spec 필수 문서·traceability·index 포인터·링크 검증, `python3 scripts/check-ai-readiness.py`
- 운영: `backend/` 또는 `frontend/` 코드 변경이 있으므로 `docker compose -f compose.local.yaml up -d --build`, 컨테이너 상태, 관련 health endpoint 확인

## T1 Work Start Checkpoint

- 대상 spec: `2026-07-21-ai-quality-versioning`, 티켓 `T1`
- 위험도: `High-risk` — `analysis_history` 스키마와 AI 결과 저장 경계를 변경한다.
- 변경 범위: 내부 모델·프롬프트 버전 컬럼, 저장 모델/Repository/provider 전달, T1 기능·회귀 테스트, T1 상태·추적성 기록
- 제외 범위: 공개 API/UI 노출, 사용자 피드백(T2), AI 호출 정책·비밀값 변경
- 테스트 경계: `AnalysisHistoryRepository` 내부 저장 계약과 Analysis History REST 응답의 메타데이터 비노출/기존 계약 회귀
- 검증 계획: T1 관련 테스트 → backend 전체 테스트·빌드 → 문서 게이트 → Compose 재빌드·health 확인
- High-risk PR 게이트: PR 생성 뒤 `scripts/pr-review-gate.sh <PR_NUMBER>`를 실행한다. 수동 확인은 신규 외부 API 호출·비밀값·배포 정책 변경이 없고, 실행 메타데이터가 DB 내부에만 남아 공개 API/UI에 노출되지 않는지로 한정한다.
- PR 범위: T1 하나만 포함하며 T2·PR #170·Issue #171 변경은 포함하지 않는다.
