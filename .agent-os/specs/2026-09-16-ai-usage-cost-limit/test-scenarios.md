## 테스트 시나리오

외부 Gemini 실호출 없이 fake provider와 H2/PostgreSQL 호환 JDBC로 검증한다.

- TC-01: limit 이내 분석의 history 생성과 used +1을 확인한다.
- TC-02: 초과 시 provider/history 0, 429, 네 가지 metadata를 확인한다.
- TC-03: 동시 reserve 성공 수가 limit 이하인지 확인한다.
- TC-04: 같은 user/key 재사용과 provider 재실행 없음을 확인한다.
- TC-05: 다른 user의 같은 key가 격리되는지 확인한다.
- TC-06: 입력·파일 validation 오류의 quota 무소비를 확인한다.
- TC-07: provider timeout 기본값과 override를 확인한다.

게이트는 Gradle test, frontend lint/test/build, AI readiness, PR 검증이다. Docker 부재로 Compose/health는 미실행하고 사유를 기록한다.
