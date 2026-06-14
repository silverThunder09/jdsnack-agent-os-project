# 프론트 SaaS 셸 재설계 계획

## Summary

대시보드 화면을 목업(SaaS형 셸: 사이드바+상단바+히어로+통합 입력+요약 카드+상세 프리뷰)으로 비주얼/UX를 전면 재설계한다. **frontend 한정, 백엔드 API·계약 불변.** 백엔드 없는 목업 기능은 구현하지 않고 셸만 채택해 기존 진단/매칭/면접에 매핑한다.

## 변경 범위

- 새 active spec 추가, 직전 대시보드 spec archive 이동, `.agent-os/standards/index.yml`·`AGENTS.md` 활성 spec 갱신(이 문서 PR).
- 구현(별도 Codex 작업): `frontend/` 셸·화면 재구성.

## 구현 지침 (Codex)

- 셸: `AppShell.tsx`를 사이드바|상단바|본문 셸로 확장. 사이드바는 전체 메뉴 노출, 홈/모의 면접만 활성, 나머지 잠금(`aria-disabled`). 계정/프로필·플랜 영역 없음.
- 라우팅: `react-router-dom` 도입(`/` 홈, `/interview` 모의 면접) 권장. 미도입 시 뷰 상태 전환.
- 홈: 히어로 + 통합 입력(JD 링크/붙여넣기 + 이력서 Text/PDF/DOCX) + 단일 `분석 시작`(진단+매칭 동시 호출) + 요약 카드(진단 점수, JD 적합도) + 상세 프리뷰(진단 강점/개선, 매칭 강점/gap/제안).
- 모의 면접: 직무(+선택 맥락) 입력 + 질문 생성 결과(질문/전략/요약).
- 재사용: 입력 컴포넌트(`ResumeInput`/`ResumeFileInput`/`ResumeModeTabs`/`JdInputFields`/`DiagnoseButton`/`StatusMessage`), 훅(`useDiagnose`/`useMatchPreview`/`useInterviewPreview`), `services/api.ts`, `types/diagnosis.ts` 그대로.
- 스타일: 목업 디자인 랭귀지(인디고 강조·둥근 카드·배지·프로그레스)로 `App.css` 재작성. 아이콘은 `lucide-react` 또는 인라인 SVG.
- 검증: `npm run lint`, `npm test`, `npm run build`, `npm run test:e2e` 통과. `App.test.tsx`·`e2e/upload-and-jd-preview.spec.ts`를 셸/목적지 selector·흐름으로 갱신. `fixture` 모드 수동 확인.

## 제외 범위

- 백엔드/API 계약 변경, Gemini 응답 스키마 변경.
- ATS 분석·점수, 누락 키워드 구조화/키워드 매칭 chips, 맞춤 첨삭(문장), 키워드 사전, 템플릿.
- 인증/계정/프로필, 분석 내역(history)·영속성, 이력서 관리, 요금제/결제.
- 제품명 변경(JDSnack 유지). diagnose+match 기능 통합·재정의(별도 논의).

## 컨테이너 운영 기준

- 로컬 개발/검증은 `compose.local.yaml`(또는 `npm run dev`) 기준.
- 배포 영향 없음(프론트 화면 변경). 배포 실행은 사용자 지시 시 Codex가 수행.
