# AI 품질 평가와 prompt/model version 구현 계획

## 상태

- Feature Spec 상태: `active`
- 구현 상태: `T1 completed, T2 pending`

## 내부 수직 티켓

### T1. Prompt/Model Version 내부 기록

- 범위: `analysis_history` 스키마에 `diagnosis_model_name`, `diagnosis_prompt_version`, `match_model_name`, `match_prompt_version` 내부 컬럼 추가, `AnalysisHistory` record·repository INSERT/rowMapper 갱신, `GeminiDiagnosisProvider`/`GeminiMatchPreviewProvider` 결과 저장 시 모델명·프롬프트 버전 함께 전달, 공개 응답 DTO에는 매핑하지 않음, 기능 테스트
- 의존성: 없음 (현재 `analysis_history`/`analysis_input_snapshot` 스키마, `.agent-os/adr/adr-019-postgresql-service-storage.md`, `.agent-os/adr/adr-020-analysis-input-record.md`)
- 완료 조건: AC-01~AC-03, TC-01~TC-04
- 상태: `completed`
- 완료 근거: `AnalysisHistoryControllerTest`로 생성·파일 생성·목록·상세·재시도 응답 비노출과 내부 저장을, `AnalysisHistoryPartialFailureTest`로 매칭 실패 시 진단 메타데이터만 보존되는 경계를 검증했다. `./gradlew test bootJar --no-daemon`, Docs Harness, AI-readiness, Compose 재빌드·health 검증을 통과했다.
- 구현 예상 위치: `backend/src/main/resources/schema.sql`, `backend/src/main/java/com/jdsnack/analysis/AnalysisHistory.java`, `backend/src/main/java/com/jdsnack/analysis/**Repository*.java`, `backend/src/main/java/com/jdsnack/diagnose/GeminiDiagnosisProvider.java`, `backend/src/main/java/com/jdsnack/match/GeminiMatchPreviewProvider.java`

### T2. 사용자 품질 피드백

- 범위: `analysis_feedback` 테이블 신설(이력당 사용자 1건, upsert), `POST /api/analysis-histories/{historyId}/feedback`, `GET /api/analysis-histories/{historyId}` 응답에 `feedback` 필드 추가, 이력 삭제 시 피드백 연쇄 삭제, `AnalysisHistoryView` 피드백 위젯, 기능 테스트
- 의존성: T1 완료(같은 Feature Spec 내 순차 진행), 기존 `GET/DELETE/retry /api/analysis-histories/**` 소유권·상태 경계 재사용
- 완료 조건: AC-04~AC-07, TC-05~TC-13
- 상태: `pending`
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
- PR 범위: T1 하나만 포함하며 T2·PR #170·Issue #171 변경은 포함하지 않는다.
