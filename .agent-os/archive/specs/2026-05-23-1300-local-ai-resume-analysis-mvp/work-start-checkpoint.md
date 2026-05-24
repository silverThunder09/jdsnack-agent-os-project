# Work Start Checkpoint

- Risk Level: High-risk
- 목적: 로컬 전용 Gemini 이력서 분석 MVP 연결
- 범위:
  - backend Gemini provider/runtime mode
  - frontend 결과 화면 문구 및 에러 분기
  - 2차 MVP spec 문서 추가
- 제외:
  - JD AI 매칭
  - 사용자 키 입력 UI
  - 운영 배포용 Gemini 연동
- 필수 검증:
  - `./gradlew test`
  - `./gradlew bootJar`
  - `npm test -- --run`
  - `npm run build`
