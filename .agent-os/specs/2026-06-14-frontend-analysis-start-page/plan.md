# 새로운 분석 시작 페이지 재구성 계획

## Summary

목업 "새로운 분석 시작"대로 home을 3단계 입력 페이지(JD 입력 / 이력서 업로드 / 분석 옵션) + 우측 안내 레일로 재구성하고, `분석 시작하기` 후 결과 화면으로 전환한다. frontend 한정·API 계약 불변. 분석 옵션은 라벨은 목업대로, 동작은 기존 기능에 매핑(JD 적합도=매칭, 나머지 준비중).

## 변경 범위

- 새 active spec 추가, 직전 `2026-06-14-frontend-saas-shell-redesign` spec archive 이동, `index.yml`·`AGENTS.md` 활성 spec 갱신, `CLAUDE.md` 폴백 규칙 추가(이 문서 PR).
- 구현: `frontend/` 재구성. **Codex 토큰 부재로 이번 구현은 Claude가 직접 수행**(CLAUDE.md 폴백 규칙).

## 구현 지침

- 셸: `AppShell.tsx` 확장(사이드바 전체 노출·홈/모의면접 활성·나머지 잠금·프로필 정적, 상단바).
- 홈(`/`): 단계형 입력 + 우측 안내 레일. JD 탭(링크=`jd/fetch` / 붙여넣기=textarea+글자수), 이력서 업로드(PDF/DOCX, `ResumeFileInput` 재사용), 옵션 체크박스 4(JD 적합도 동작 / ATS·문장첨삭·키워드 준비중), `분석 시작하기`.
- 실행: 검증 → `diagnose/file`로 본문 추출 → `match` → 결과 뷰. 준비중 옵션은 준비중 패널.
- 결과 뷰: `SummaryCard`/`AnalysisPanel`/`EmptyState` 재사용 + 준비중 패널 + `새 분석`.
- 모의 면접: 기존 흐름 유지.
- 훅·서비스(`useDiagnose`/`useMatchPreview`/`useInterviewPreview`/`api.ts`/`types`)·계약 불변.
- 검증: `npm run lint`, `npm test`, `npm run build`, `npm run test:e2e` 통과. `App.test.tsx`·`e2e/upload-and-jd-preview.spec.ts` 갱신. `fixture` 모드 수동 확인.

## 제외 범위

- 백엔드/API 계약 변경, Gemini 응답 스키마 변경.
- ATS·문장 첨삭·키워드 분석의 실제 구현(준비중 표시만).
- 키워드 사전·템플릿·분석 내역·이력서 관리·요금제·인증의 실제 구현(사이드바 잠금/프로필 정적만).
- TXT 등 백엔드 미지원 형식.

## 컨테이너 운영 기준

- 로컬 개발/검증은 `compose.local.yaml`(또는 `npm run dev`) 기준. 배포 영향 없음(프론트 변경).
