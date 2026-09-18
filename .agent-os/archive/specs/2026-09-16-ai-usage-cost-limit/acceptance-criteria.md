## 수용 기준

- AC-01: 한도 이내 인증 분석은 history 생성과 사용량 +1을 남긴다.
- AC-02: 초과 요청은 provider/history 없이 429와 네 가지 quota metadata를 반환한다.
- AC-03: 같은 user/key는 history를 재사용하고 다른 user는 독립 처리한다.
- AC-04: 입력·파일 validation 오류는 quota를 소비하지 않는다.
- AC-05: 동시 예약 성공 수는 limit 이하이고 ledger는 중복되지 않는다.
- AC-06: Gemini timeout 기본값과 override가 분석·매칭 오류 계약을 유지한다.

모든 AC는 TC·traceability와 연결하며 backend/frontend·AI readiness 게이트를 통과한다. Compose/health 미검증 사유는 기록한다.
