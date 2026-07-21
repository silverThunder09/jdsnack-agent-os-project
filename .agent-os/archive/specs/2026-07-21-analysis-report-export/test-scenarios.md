# 분석 결과 리포트 내보내기 테스트 시나리오

테스트는 외부 서비스 실호출 대신 fixture, fake, stub, 주입 가능한 client를 우선 사용합니다.

## UI

- **TC-01 성공 이력 내보내기**: `SUCCEEDED` 이력 상세에서 내보내기 진입점을 사용하면 Markdown 파일 다운로드가 트리거되는지 확인한다.
- **TC-02 소유권 경계 유지**: 본인 소유가 아닌 이력 ID로 상세 조회 시 기존 `ANALYSIS_HISTORY_NOT_FOUND` 경계가 유지되어 내보내기 진입점 자체가 노출되지 않는지 확인한다.
- **TC-03 저장된 결과만 포함**: `match` 결과가 없는 이력을 내보낼 때 JD 적합도·키워드 섹션이 생략되고 `diagnosis` 섹션만 포함되는지 확인한다.
- **TC-04 파일명·content type**: 내려받은 파일명에 이력 식별자와 생성일이 포함되고 `text/markdown` content type인지 확인한다.
- **TC-05 진행 중·실패 이력 처리**: `RUNNING`·`FAILED` 이력에서 내보내기 진입점이 비활성이거나, 결과 없음 안내가 표시되고 빈 성공 리포트가 생성되지 않는지 확인한다.

## 회귀

- **TC-06 정적 품질 게이트**: 프론트 lint/test/build/E2E, Docs Harness, 기존 `AnalysisResultView` 실시간 내보내기 회귀가 통과하는지 확인한다.

## 검증 명령

- 프론트 영향: `cd frontend && npm run lint && npm test && npm run build`
- 통합 영향: `cd frontend && npm run test:e2e`
- 문서: `python3 scripts/check-ai-readiness.py`
