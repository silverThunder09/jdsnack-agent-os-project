# 결과 내보내기·입력 자동저장 계획

## Summary

"새로운 분석 시작" 페이지에 **결과 내보내기(마크다운 다운로드 + 인쇄)**와 **입력 자동저장·복원(JD 본문·옵션, 이력서 제외)**을 추가한다. frontend 한정·API 계약 불변. Codex 토큰 부재로 이번 구현도 Claude가 직접 수행(CLAUDE.md 폴백).

## 변경 범위

- 새 active spec 추가, 직전 `2026-06-14-frontend-analysis-start-page` spec archive 이동, `index.yml`·`AGENTS.md` 활성 spec 갱신(이 문서 PR).
- 구현: `frontend/` (App.tsx 결과 화면에 버튼·핸들러 + 입력 상태 localStorage 연동).

## 구현 지침

- 내보내기: `result.matchPreview`를 마크다운 문자열로 변환 → Blob + `a[download]`로 `.md` 저장. 인쇄는 `window.print()`. 결과 success일 때만 버튼 노출.
- 자동저장: `jdText`·`options`를 `localStorage`(키 `jdsnack.analysis-input`)에 저장/복원. 이력서 파일 제외. "입력 초기화" 버튼으로 상태·저장 삭제.
- 결과 표시·셸·훅 변경 없음. 추가 버튼만.
- 검증: `npm run lint`, `npm test`, `npm run build`, `npm run test:e2e` 통과. 단위·e2e에 내보내기/복원 케이스 추가. `fixture` 모드 수동 확인.

## 제외 범위

- 백엔드/API 계약 변경, 서버 저장.
- 결과 복사(클립보드)·다크모드(이번 범위 아님).
- 이력서 파일·추출 본문의 로컬 영속화.

## 컨테이너 운영 기준

- 로컬 개발/검증은 `compose.local.yaml`(또는 `npm run dev`) 기준. 배포 영향 없음.
