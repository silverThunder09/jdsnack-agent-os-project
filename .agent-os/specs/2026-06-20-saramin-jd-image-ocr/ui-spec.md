# 사람인 JD 이미지 OCR 폴백 UI 명세

## 결론: 프론트 무변경

본 기능은 **백엔드 전용 폴백**이다. 프론트(`frontend/src` 전체)는 변경하지 않는다.

## 근거

- JD 링크 수집은 프론트 `frontend/src/services/api.ts`의 `fetchJdFromUrl()`(약 274행, `POST /api/jd/fetch`)이 호출하고, 응답을 `JdFetchResult`(`frontend/src/types/diagnosis.ts` 약 95~103행)로 매핑한다. 성공 시 `result.jdText`가 기존 흐름(`frontend/src/hooks/useMatchPreview.ts` 약 252행 `fetchJdFromUrl(jdUrl.trim())`)으로 JD 입력에 채워진다.
- 이미지 OCR 폴백은 서버가 동일한 `JdFetchResponse`에 `jdText`를 채워 돌려주므로, 프론트는 텍스트 추출과 이미지 OCR을 구별하지 않고 동일하게 처리한다.
- `JdFetchResult.fetchMode`는 이미 `fetchMode: string`(자유 문자열) 타입이라 신규 값 `"image-ocr"`를 타입 변경 없이 수용한다. 프론트는 `fetchMode`로 분기 표시하는 로직이 없으므로 UI 영향이 없다.

## 명시적으로 하지 않는 것

- "이미지에서 추출됨" 같은 출처 배지/표기는 **범위 밖**이다(추가하지 않는다).
- JD 입력 화면, 분석 옵션, 결과 화면, 사이드바, 내보내기 마크다운 등 어떤 프론트 UI도 변경하지 않는다.
- 프론트 타입(`diagnosis.ts`)·서비스(`api.ts`)·훅(`useMatchPreview.ts`)에 신규 필드/분기를 추가하지 않는다.

## 검증 관점 (프론트)

- 프론트 변경이 없으므로 기존 프론트 테스트(`npm run lint`/`npm test`/`npm run build`/`npm run test:e2e`)는 수정 없이 그대로 통과해야 한다. `fetchMode`가 `"image-ocr"`여도 기존 JD fetch 성공 흐름(JD 텍스트 채움)이 동일하게 동작함을 e2e/단위 레벨에서 회귀로만 확인한다(신규 단언 추가 불필요).
