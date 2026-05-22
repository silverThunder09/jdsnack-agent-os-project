# 테스트 표준

## 목적

테스트는 “있으면 좋은 것”이 아니라 문서 계약을 검증하는 하네스입니다.

## 기본 규칙

- acceptance criteria 없는 테스트는 방향을 잃기 쉽습니다.
- test scenario 없는 acceptance criteria는 검증되지 않은 요구사항입니다.
- 가능하면 테스트명 또는 주석에 `AC-xx`, `TC-xx`를 연결합니다.

## 필수 검증 범주

- 정상 흐름
- 예외 흐름
- 경계값
- 외부 API 실패 또는 지연은 2차 MVP부터 적용
- 문서 계약과 실제 응답 일치 여부

## JDSnack MVP 기준 필수 시나리오

- 정상 이력서 입력 시 `AI_ANALYSIS_NOT_ENABLED` 반환
- 빈 입력 시 검증 실패
- 너무 짧은 입력 시 검증 실패
- 너무 긴 입력 시 검증 실패
- 프론트에서 입력 -> 로딩 -> 준비중 안내 흐름 유지
- compose 기반 스모크 테스트에서 프론트 프록시 -> 백엔드 검증 흐름 유지

## 스모크 테스트 원칙

- 스모크 테스트는 전체 기능을 깊게 검증하지 않는다.
- 대신 사용자가 가장 먼저 밟는 경로가 살아 있는지만 빠르게 확인한다.
- 1차 MVP에서는 브라우저 루트 응답, 프론트 프록시, 짧은 입력 검증, 준비중 응답까지를 최소 범위로 본다.

## 문서 연결

- 기능별 상세 시나리오는 각 spec의 `test-scenarios.md`를 기준 문서로 봅니다.
- 공통 완료 기준은 [definition-of-done.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/standards/definition-of-done.md)를 따릅니다.
