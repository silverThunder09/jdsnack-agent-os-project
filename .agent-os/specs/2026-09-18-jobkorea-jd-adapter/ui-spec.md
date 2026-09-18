## UI 계약

- JD 링크 탭의 기존 idle/loading/success/error 흐름과 붙여넣기 탭 대체 경로를 그대로 유지한다. 새 화면·새 탭은 추가하지 않는다.
- 지원 사이트 안내 문구에 JobKorea를 포함하고, 지원하지 않는 링크는 본문 붙여넣기로 진행하라는 기존 안내를 유지한다.
- 정적 HTML 본문이 부족한 사람인·잡코리아 이미지형 공고는 OCR fallback을 시도한다. `fetchMode=image-ocr` 성공 시 "이미지형 채용 공고를 OCR로 인식"했다는 문구와 결과 확인·수정 안내를 표시하고, 자동으로 인식한 텍스트를 JD 입력 영역에 채운다.
- JD 링크 host로 출처를 판별해 분석 요청에 전송한다. 사람인 host는 `SARAMIN_URL`/`saramin`, JobKorea host는 `JOBKOREA_URL`/`jobkorea`, 링크 미입력은 `TEXT`/`null`이다. 출처 문자열을 화면에서 하드코딩해 항상 `saramin`으로 보내지 않는다.
- 수집 실패 안내는 error code로 구분한다. `INVALID_JD_URL`은 링크 형식 문제, `JD_FETCH_UNSUPPORTED_SOURCE`는 미지원 링크, `JD_FETCH_EMPTY_CONTENT`는 본문 추출 실패, `JD_FETCH_FAILED`는 일시 오류로 안내하고 각각 붙여넣기 대안을 제시한다.
- OCR 공급자 미설정·이미지 다운로드 거부·OCR 예외·품질 미달은 원래 수집 error code와 동일한 실패 안내로 처리하며, 내부 예외·이미지 URL·OCR raw 응답은 화면에 노출하지 않는다.
- 상태는 색상만으로 구분하지 않고 문구와 `role="alert"`를 함께 사용한다. 원문 HTML·내부 예외 메시지는 표시하지 않는다.
- 분석 이력 상세의 출처 표기는 저장된 `sourceSite` 값을 사용하고, 값이 없으면 기존 직접 입력 표기를 유지한다.
- 저장된 `sourceSite=jobkorea`는 화면에서 `잡코리아`로 표시하고, OCR로 저장된 이력도 일반 링크 이력과 동일한 조회·재시도·내보내기 흐름을 사용한다.
- API 호출·오류 해석은 `frontend/src/services/api.ts`가 담당하고 컴포넌트는 직접 fetch하지 않는다. 링크·출처 값은 비밀값이 아니며 프론트에 비밀 키를 입력·저장하는 흐름은 만들지 않는다.
- Compose/health 미검증 사유는 공통 검증 기록에 남긴다.
