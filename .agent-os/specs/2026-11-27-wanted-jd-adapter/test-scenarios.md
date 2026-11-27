# 테스트 시나리오

| ID | 시나리오 | 기대 결과 |
|---|---|---|
| TC-01 | 숫자형 Wanted 공고 URL | WANTED_URL, wanted |
| TC-02 | 정적 HTML 직무 설명 | static-html, 본문·메타데이터 추출 |
| TC-03 | SSR 본문이 없고 Next.js 데이터 존재 | 데이터 필드로 본문 생성 |
| TC-04 | 추천/지원 문구만 존재 | 빈 본문 오류 |
| TC-05 | 종료·숨김 공고 | 지원하지 않는 출처 오류 |
| TC-06 | 허용 이미지 OCR 성공 | image-ocr snapshot |
| TC-07 | OCR에 직무 섹션 신호 없음 | 실패, snapshot 미저장 |
| TC-08 | 비허용 호스트·redirect·사설 IP | 외부 요청 차단 |
| TC-09 | 비 HTML 응답·초과 크기 | 수집 실패 |
| TC-10 | 분석 이력 생성 및 재시도 | 원본 URL·출처·방식·JD snapshot 불변 |
| TC-11 | 구현 및 요청 계약 검사 | 로그인·지원 자동화·API 키 연동 없음 |
