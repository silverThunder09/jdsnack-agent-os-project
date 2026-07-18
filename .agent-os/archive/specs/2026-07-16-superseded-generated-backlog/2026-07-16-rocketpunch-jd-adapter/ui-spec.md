# RocketPunch JD source adapter UI 명세

## 사용자 흐름

RocketPunch URL 입력·수집 성공·실패 상태를 기존 JD 입력 흐름에 연결합니다.

## 상태

- idle: 입력 또는 진입 전
- loading: 서버·외부 작업 진행
- success: 계약에 맞는 결과 표시
- error: 사용자에게 안전한 안내와 재시도 가능 여부 표시

## 접근성·회귀

- 비동기 상태는 시각 정보만으로 구분하지 않습니다.
- 기존 분석 입력·결과 흐름을 깨뜨리지 않습니다.
