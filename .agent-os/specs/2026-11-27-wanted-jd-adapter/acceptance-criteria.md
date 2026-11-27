# 수용 기준

- [ ] AC-01 숫자형 /wd/{id} URL이 WANTED_URL과 wanted로 식별된다.
- [ ] AC-02 실제 Wanted HTML의 직무 설명을 추출하고 추천·지원 UI 노이즈를 제외한다.
- [ ] AC-03 SSR 본문이 부족하면 embedded Next.js 데이터의 업무·요건 필드를 추출한다.
- [ ] AC-04 종료·숨김·비공개 공고 및 본문 품질 미달은 실패한다.
- [ ] AC-05 허용된 설명 이미지에 한해 OCR을 실행하고 품질 미달 결과를 거부한다.
- [ ] AC-06 분석 이력에 URL·sourceSite·fetchMode·당시 JD snapshot을 저장한다.
- [ ] AC-07 허용되지 않은 URL·redirect·이미지·응답은 외부 요청 전에 차단한다.
- [ ] AC-08 로그인·지원 자동화·전용 API 키 연동이 없다.
