# 분석 결과 리포트 내보내기 구현 계획

## 상태

- Feature Spec 상태: `completed`
- 구현 상태: `completed`

## 내부 수직 티켓

### T1. 분석 내역 상세 Markdown 내보내기

- 범위: `AnalysisHistoryView` 상세 내보내기 진입점, 이력 저장 결과 기반 Markdown 빌드, 상태별(진행 중/실패) 처리, 파일명·content type, 기능 테스트
- 의존성: 기존 `GET /api/analysis-histories/{historyId}` 소유권 검증, 기존 `buildResultMarkdown` 패턴
- 완료 조건: AC-01~AC-06, TC-01~TC-06
- 상태: `completed`
- 구현: `frontend/src/features/analysis/AnalysisHistoryView.tsx`, `frontend/src/features/analysis/analysisUtils.ts`, `frontend/src/App.tsx`
- 기능 테스트: `frontend/src/features/analysis/analysisUtils.test.ts`

## T1 검증 결과

- `cd frontend && npm run lint`: passed
- `cd frontend && npm test`: passed (4 files, 29 tests)
- `cd frontend && npm run build`: passed
- `git diff --check`: passed
- `docker compose -f compose.local.yaml up -d --build`: 별도 Docker 검증에서 확인 예정

## 공통 검증

- 프론트: `cd frontend && npm run lint`, `npm test`, `npm run build`, `npm run test:e2e`
- 문서: active spec 필수 문서·traceability·index 포인터·링크 검증, `python3 scripts/check-ai-readiness.py`
- 운영: 백엔드 변경이 없으므로 `docker compose -f compose.local.yaml up -d --build`와 프론트 컨테이너 상태·smoke test로 검증한다.
