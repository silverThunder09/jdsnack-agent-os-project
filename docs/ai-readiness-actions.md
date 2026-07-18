# JDSnack AI-Readiness 후속 액션

현재 자동 점수는 **76/100 · AI-Ready**입니다. 이전 주요 부족 사항(진입 문서, 의존성 지도, 링크/신선도 gate, 정적 eval, 500줄 초과 진입 파일)은 반영했습니다.

| 우선순위 | 남은 액션 | 효과 |
|---:|---|---|
| 1 | 기능 변경 전후에 로컬 Codex eval 실행 | 필요할 때만 context-on/off pass-rate·경로·검증·제약·토큰 지표 수집 |
| 2 | PR/이슈 telemetry를 연결해 재작업률 기록 | 계획 품질을 실제 구현 결과까지 확장 |
| 3 | 기능 변경 시 `api.ts`, `useMatchPreview.ts`의 다음 책임 단위 분리 | 변경 범위와 컨텍스트 크기 축소 |

## 이번에 해소한 이슈

- `backend/README.md`, `frontend/README.md`, `scripts/README.md`에 Purpose·Key files·Patterns·Gotchas·Dependencies·Commands를 추가했습니다.
- `docs/ARCHITECTURE.md`와 상세 Mermaid map으로 프론트 → API → 도메인/외부 연동의 변경 영향을 연결했습니다.
- `.agent-os/ai-readiness.yml`, `scripts/check-ai-readiness.py`, `evals/context-tasks.json`을 추가하고 Docs Harness CI에 연결했습니다.
- `.githooks/pre-commit`을 추가했습니다. 모델 eval은 API 비용을 피하기 위해 CI 스케줄 없이 로컬 Codex 로그인 세션에서만 실행합니다.
- 문서 링크를 정리하고 stale archive 링크를 제거했습니다.
- `App.tsx`, `JdFetchService`, `JdHtmlExtractor`를 책임 단위로 분리했습니다.

## 자동 점수 해석

자동 scorer의 `.agent-os` 경로 정규식은 유효한 경로를 `os/...`로 잘라 false positive를 냅니다. 실제 readiness gate는 전체 비archive Markdown 링크와 정적 eval 경로를 검사해 통과했습니다. Mermaid도 존재하지만 scorer가 README/AGENTS만 탐색해 D 항목의 일부를 놓칩니다.
