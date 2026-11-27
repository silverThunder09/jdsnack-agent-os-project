# API 명세

기존 JD fetch 및 분석 이력 API를 유지한다.

- JD URL fetch: 기존 요청 jdUrl에 Wanted 공개 공고 URL을 전달한다.
- 응답: jdText, sourceUrl, title, fetchMode, sourceSite를 기존 계약대로 반환한다.
- 출처 값: sourceSite=wanted, 입력 유형 WANTED_URL.
- fetchMode: 정적 HTML 및 JSON 본문은 static-html, 이미지 인식은 image-ocr.
- 오류: URL 형식 오류 INVALID_JD_URL, 빈 본문 JD_FETCH_EMPTY_CONTENT, 종료·품질·출처 불일치 JD_FETCH_UNSUPPORTED_SOURCE, 수집·redirect 오류 JD_FETCH_FAILED.
- 이력 생성 시 기존 multipart 계약의 sourceUrl을 다시 fetch하여 snapshot을 생성한다. 저장된 이력의 재시도는 기존 snapshot을 사용한다.
