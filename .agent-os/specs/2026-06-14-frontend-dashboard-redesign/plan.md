# 프론트 대시보드 전면 재설계 계획

## Summary

3단계 위저드 화면을 입력·결과를 한 화면에서 보는 대시보드형으로 전면 재설계한다. 백엔드 API와 기능 동작은 불변이며, 변경은 `frontend/` 한정이다.

## 변경 범위

- 새 active spec 추가, 기존 모의 면접 spec archive 이동, `.agent-os/standards/index.yml`·`AGENTS.md` active spec 갱신(이 문서 PR).
- 구현(별도 Codex 작업): `frontend/` 화면 재구성.

## 구현 지침 (Codex)

- 레이아웃: `App.tsx`를 대시보드(입력 레일 | 결과 영역) 2단으로 재구성. 위저드 상태(`currentStep`/`activeStep`)와 `StepProgress`, 단계 전환 핸들러 제거.
- 입력 레일: 기존 `ResumeStep`/`JdStep`의 입력 요소(이력서 Text/PDF/DOCX, JD 섹션·링크, 대상 직무)와 실행 버튼을 한 영역으로 재배치. 입력 컴포넌트(`ResumeInput`/`ResumeFileInput`/`ResumeModeTabs`/`JdInputFields`)는 가능한 재사용.
- 결과 영역: 진단·매칭·면접 결과 패널 3개를 세로 배치. `ReportStep`/`ResultPanel`의 표시 로직을 패널 단위로 재배치. 빈/로딩/성공/실패 상태를 패널 내부에서 처리.
- 훅 재사용: `useDiagnose`/`useMatchPreview`/`useInterviewPreview`와 `services/api.ts`는 그대로 사용(계약 불변). resume source 전달 방식 유지.
- 상단 바: 프로필/계정 버튼 제거, 브랜드만. `STEP` 라벨 제거.
- 스타일: `App.css`를 대시보드 그리드/패널 기준으로 정리(반응형 2단↔세로 스택). 사용하지 않게 된 위저드 스타일 제거.
- 테스트: `App.test.tsx` 단위 테스트와 `e2e/upload-and-jd-preview.spec.ts`를 대시보드 흐름·selector로 갱신. 위저드 단계 전환 가정 제거.
- 검증: `cd frontend && npm run lint`, `npm test`, `npm run build` 통과. `fixture` 모드로 세 패널 표시 수동 확인.

## 제외 범위

- 백엔드/API 계약 변경, Gemini 응답 스키마 변경.
- diagnose와 match 기능 통합·재정의(별도 논의 대상).
- 인증/프로필 기능 신규 추가(프로필 버튼은 제거만).
- 운영 배포 변경.

## 컨테이너 운영 기준

- 로컬 개발/검증은 `compose.local.yaml`(또는 `npm run dev`) 기준.
- 배포 영향 없음(프론트 화면 변경). 배포 실행은 사용자 지시 시 Codex가 수행.
