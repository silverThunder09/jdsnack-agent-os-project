# 분석 실행 전 통합 검증 게이트 UI 명세

## 게이트 위치

- 대상: "새로운 분석 시작" 입력 화면(`frontend/src/App.tsx`)의 분석 시작 버튼과 그 주변 입력 영역.
- 현행 `canStart`(약 289행)는 `Boolean(resumeFile) && Boolean(trimmedJd) && selectedOptionKeys.length > 0`로, JD 최소 길이를 보지 않는다. 이를 **통합 검증 결과**로 대체한다.

## 통합 검증 모델 (프론트)

- 단일 검증 함수/메모이즈된 값으로 다음을 한 번에 평가한다.
  - 이력서: 파일 모드면 "지원 형식 파일 선택됨", 텍스트 모드면 `validateResumeText`(50/10,000) 통과.
  - JD: `validateJdText`(50/10,000) 통과.
  - 분석 항목: `selectedOptionKeys.length > 0`.
- 산출물: `{ canStart: boolean, reasons: string[] }`(또는 항목별 사유 맵). 기존 `validateJdText`/`validateResumeText` 함수를 재사용해 기준 중복을 피한다.
- JD 길이 검증을 **매칭 요청 직전(`useMatchPreview.submit`)이 아니라 게이트 단계로 끌어올린다.** 매칭 직전 검증은 방어선으로 남겨 둘 수 있으나, 게이트가 1차 차단을 책임진다.

## 게이팅 동작

- `canStart`가 false면 분석 시작 버튼을 비활성(`disabled` + `aria-disabled`)으로 둔다.
- 버튼 하단/주변에 미통과 사유를 인라인으로 표시한다(기존 `formError` 표시 자리 활용 가능). 사유 문구는 기존 검증 메시지를 재사용한다:
  - 이력서 미선택: "이력서 파일을 업로드해 주세요."
  - JD 짧음: "JD 내용이 너무 짧습니다. 핵심 자격요건이 드러나도록 더 입력해주세요." (또는 현행 프론트 메시지)
  - 분석 항목 0개: "분석 항목을 1개 이상 선택해 주세요."
- 버튼이 비활성인 동안에는 클릭/제출 핸들러가 실행되지 않아 `submitFile`/`submitPreview` 등 네트워크 호출이 시작되지 않는다.

## 호출 차단 순서

- 현행 `handleSubmit`(약 380~414행)은 파일 검증 → mode 추론 → `validateJdText` → 옵션 검증 후 `submitFile`/`submitPreview`를 호출한다. 이 검증들이 **버튼 활성 조건에도 동일하게 반영**되어, 짧은 JD 상태에서는 버튼 자체가 눌리지 않아 `/api/diagnose/file` 업로드가 시작되지 않게 한다.
- 안전망: 핸들러 진입부의 기존 가드(early return)는 유지한다(이중 방어).

## 접근성·반응형

- 비활성 버튼은 명확한 텍스트 label과 `aria-disabled`를 가진다.
- 인라인 사유는 입력 영역과 시각적으로 연결되며, 좁은 폭에서도 줄바꿈되어 겹치지 않는다.
- 가능하면 사유 영역에 `role="status"` 또는 `aria-live="polite"`로 변경을 알린다(선택).

## 마이그레이션 메모

- 기준 임계값(50/10,000)은 새로 정의하지 않고 기존 `validateJdText`/`validateResumeText`를 재사용한다.
- 파일 모드 이력서의 본문 최소 길이는 프론트에서 알 수 없으므로 게이트 통과 조건에 넣지 않는다(백엔드 재검증 책임).
- 결과 화면·셸·기존 결과 표시 컴포넌트는 변경하지 않는다. 입력 화면의 게이팅만 손댄다.
