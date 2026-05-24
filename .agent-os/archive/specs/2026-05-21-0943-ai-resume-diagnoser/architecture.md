# 아키텍처 문서

> 프로젝트: JDSnack — 1차 MVP 서비스 뼈대  
> 기준 결정: 1차 MVP는 외부 AI 호출 없이 입력 검증과 준비중 안내까지만 구현한다.

## 1. 시스템 개요

JDSnack 1차 MVP는 React 프론트엔드와 Spring Boot 백엔드를 하나의 서비스 구조로 준비한다.  
이 단계의 목적은 실제 AI 분석보다, 요청 흐름과 검증 기준을 안정적으로 만드는 것이다.

## 2. 런타임 흐름

```text
[1] 사용자 브라우저
    |
    | GET /
    v
[2] React SPA
    |
    | 사용자가 이력서 텍스트 입력
    | POST /api/diagnose { resumeText }
    v
[3] Spring Boot Controller
    |
    | 요청 본문 수신
    v
[4] Validation Service
    |
    | 빈 입력 / 길이 검증
    v
[5] 응답 반환
    |
    | 검증 실패: 400
    | 검증 성공: 501 AI_ANALYSIS_NOT_ENABLED
    v
[6] React SPA
    |
    | 오류 또는 준비중 안내 렌더링
```

## 3. 백엔드 구조

```text
backend/
└── src/main/java/com/jdsnack/
    ├── JDSnackApplication.java
    ├── controller/
    │   ├── HealthController.java
    │   └── DiagnoseController.java
    ├── service/
    │   └── DiagnoseValidationService.java
    ├── dto/
    │   ├── DiagnoseRequest.java
    │   ├── ApiResponse.java
    │   └── ErrorDetail.java
    └── exception/
        └── GlobalExceptionHandler.java
```

## 4. 백엔드 계층 책임

| 계층 | 책임 |
|---|---|
| Controller | HTTP 요청/응답 처리, Service 호출 |
| Validation Service | 이력서 입력값 검증, 1차 MVP 준비중 상태 결정 |
| DTO | 요청/응답 데이터 구조 |
| Exception Handler | 검증 실패와 서버 오류를 공통 응답으로 변환 |

1차 MVP에는 외부 AI 서비스 클래스, 외부 API 클라이언트, AI 응답 파서가 포함되지 않는다.

## 5. 프론트엔드 구조

```text
frontend/
└── src/
    ├── components/
    │   ├── ResumeInput.tsx
    │   ├── DiagnoseButton.tsx
    │   ├── ResultPanel.tsx
    │   └── StatusMessage.tsx
    ├── hooks/
    │   └── useDiagnose.ts
    ├── services/
    │   └── api.ts
    └── types/
        └── diagnosis.ts
```

프론트엔드는 인증 정보 입력 UI를 제공하지 않는다. API 호출은 `services/api.ts`를 통해서만 수행한다.

## 6. API 계약

- `GET /api/health`: 서버 상태 확인
- `POST /api/diagnose`: 이력서 입력 검증
- 검증 성공 시 실제 분석 대신 `501 AI_ANALYSIS_NOT_ENABLED` 반환

## 7. 데이터 저장

- 서버 DB 없음
- 인증 없음
- 이력서 입력값은 사용자 편의를 위해 브라우저 LocalStorage에 저장할 수 있음
- LocalStorage에는 인증 정보를 저장하지 않음

## 8. 배포 방향

- 1차 목표는 백엔드와 프론트엔드를 각각 로컬에서 실행 가능한 상태로 만드는 것이다.
- 이후 React 빌드 결과물을 Spring Boot 정적 리소스로 포함해 단일 JAR 배포를 구성한다.

## 9. 2차 MVP 확장 예정

2차 MVP에서 아래 항목을 별도 설계 후 추가한다.

- 서버 환경변수 기반 외부 AI 연동
- AI 분석 결과 DTO
- 점수/피드백/요약 렌더링
- 외부 API 실패 처리
- 배포 환경의 비밀값 관리
