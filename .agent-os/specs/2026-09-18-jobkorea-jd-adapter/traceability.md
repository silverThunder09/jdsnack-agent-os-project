| 요구사항 | 수용 기준 | 테스트 시나리오 | 계약 문서 | 비고 |
| --- | --- | --- | --- | --- |
| REQ-01 | AC-01 | TC-01 | api-spec.md | JobKorea host allowlist 성공 |
| REQ-01 | AC-05 | TC-06 | api-spec.md | 비-allowlist 호스트 422 |
| REQ-02 | AC-01 | TC-01 | api-spec.md | sourceSite·fetchMode·sourceUrl 계약 |
| REQ-02 | AC-02 | TC-02 | api-spec.md | 사람인 계약 회귀 |
| REQ-03 | AC-03 | TC-01 | api-spec.md | fixture 기반 본문 추출 |
| REQ-03 | AC-03 | TC-04 | api-spec.md | 본문 부족 fixture |
| REQ-03 | AC-03 | TC-05 | api-spec.md | 오류 페이지 fixture |
| REQ-04 | AC-04 | TC-03 | api-spec.md | noise 블록 제거 |
| REQ-05 | AC-07 | TC-07 | api-spec.md | SSRF·scheme 차단 |
| REQ-05 | AC-06 | TC-09 | api-spec.md | 본문 크기 상한 |
| REQ-05 | AC-08 | TC-10 | api-spec.md | redirect 최종 호스트 |
| REQ-06 | AC-05 | TC-05 | api-spec.md | 오류 페이지·fake success 422 |
| REQ-06 | AC-06 | TC-04 | api-spec.md | 본문 50자 미만 422 |
| REQ-06 | AC-06 | TC-08 | api-spec.md | 비-2xx·네트워크 오류 502 |
| REQ-06 | AC-07 | TC-07 | api-spec.md | URL 형식·차단 호스트 400 |
| REQ-07 | AC-09 | TC-01 | test-scenarios.md | fixture·mock 전용 검증 |
| REQ-07 | AC-09 | TC-03 | test-scenarios.md | 라이브 호출·인증정보 없음 |
| REQ-08 | AC-10 | TC-11 | api-spec.md | JOBKOREA_URL 출처 저장 |
| REQ-08 | AC-10 | TC-12 | api-spec.md | SARAMIN_URL 하위 호환 |
| REQ-09 | AC-11 | TC-13 | ui-spec.md | host 기반 출처 판별 전송 |
| REQ-09 | AC-11 | TC-14 | ui-spec.md | error code별 안내·지원 사이트 문구 |

커버리지: REQ 9개, AC 11개, TC 14개가 모두 최소 1개 행에 연결된다. 티켓별 구현 결과는 [plan.md](plan.md)에 기록한다.
