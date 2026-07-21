# AI 품질 평가와 prompt/model version 구현 계획

## 상태

- Feature Spec 상태: `active`
- 구현 상태: `T1 ready, T2 pending`

## 내부 수직 티켓

### T1. Prompt/Model Version 내부 기록

- 범위: `analysis_history` 스키마에 `diagnosis_model_name`, `diagnosis_prompt_version`, `match_model_name`, `match_prompt_version` 내부 컬럼 추가, `AnalysisHistory` record·repository INSERT/rowMapper 갱신, `GeminiDiagnosisProvider`/`GeminiMatchPreviewProvider` 결과 저장 시 모델명·프롬프트 버전 함께 전달, 공개 응답 DTO에는 매핑하지 않음, 기능 테스트
- 의존성: 없음 (현재 `analysis_history`/`analysis_input_snapshot` 스키마, `.agent-os/adr/adr-019-postgresql-service-storage.md`, `.agent-os/adr/adr-020-analysis-input-record.md`)
- 완료 조건: AC-01~AC-03, TC-01~TC-04
- 상태: `ready`
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
