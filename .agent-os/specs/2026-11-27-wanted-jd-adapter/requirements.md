# 원티드 JD Source Adapter 요구사항

## REQ-01 원티드 URL 입력
- https://www.wanted.co.kr/wd/{id} 형식의 공개 공고 URL을 WANTED_URL로 식별한다.
- 프론트와 백엔드가 동일한 호스트·경로 조건을 적용한다.

## REQ-02 공고 본문 수집
- Wanted 전용 경계에서 공개 HTML 본문을 먼저 추출하고, 부족하면 __NEXT_DATA__의 공고 필드를 사용한다.
- 주요업무·자격요건·우대사항 등 직무 본문 근거가 없거나 품질 기준 미달이면 성공 처리하지 않는다.
- 마감·숨김·비공개 공고는 실패로 처리한다.

## REQ-03 이미지 OCR
- 정적 본문이 부족한 경우 공고 설명 영역에 포함된 허용 이미지에 한해 OCR을 시도한다.
- OCR 결과는 직무 섹션 신호와 기존 최소 길이·품질 기준을 통과해야 한다.

## REQ-04 출처 이력 보존
- sourceSite=wanted, WANTED_URL, fetchMode=static-html|image-ocr와 분석 시점 JD 텍스트·원본 URL을 snapshot에 보존한다.
- 재시도는 저장된 snapshot을 재사용한다.

## REQ-05 외부 요청 보안
- HTTPS/HTTP, 정확한 호스트, 공고 경로, redirect 목적지, 응답 크기·콘텐츠 타입을 검증한다.
- 이미지 redirect·호스트·크기·MIME을 source allowlist로 검증한다.
- 로그인, 지원 자동화, 원티드 API 키는 사용하지 않는다.
