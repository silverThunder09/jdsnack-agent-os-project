# 아키텍처 문서

> 프로젝트: JDSnack — 1.5차 MVP 이력서 업로드 + fixture 분석

## 1. 시스템 개요

1.5차 MVP는 1차 MVP의 입력 검증 구조를 유지하면서, 파일 업로드와 fixture 결과 반환을 추가한다.

## 2. 런타임 흐름

```text
사용자
 -> 텍스트 입력 또는 파일 업로드
 -> Frontend
 -> POST /api/diagnose 또는 POST /api/diagnose/file
 -> Controller
 -> ResumeExtractionService (파일인 경우)
 -> DiagnoseService
 -> DiagnosisProvider (mode selector)
 -> StubDiagnosisProvider 또는 FixtureDiagnosisProvider
 -> 분석 결과 반환
 -> Frontend 결과 카드 렌더링
```

## 3. 백엔드 구조 제안

```text
backend/
└── src/main/java/com/jdsnack/
    ├── diagnose/
    │   ├── DiagnoseController.java
    │   ├── DiagnoseService.java
    │   ├── DiagnosisProvider.java
    │   ├── StubDiagnosisProvider.java
    │   ├── FixtureDiagnosisProvider.java
    │   ├── ResumeExtractionService.java
    │   └── FixtureAnalysisRepository.java
```

## 4. 핵심 경계

- Controller는 HTTP 요청 수신만 담당한다.
- 파일 파싱은 `ResumeExtractionService`에서만 담당한다.
- 분석 결과 생성 또는 반환은 `DiagnosisProvider` 구현체에서만 담당한다.
- fixture 저장소는 실제 AI 로직을 흉내내지 않고, 준비된 결과를 반환만 한다.

## 5. 저장 전략

- 1.5차 MVP의 테스트 DB는 영구 사용자 데이터 저장소가 아니다.
- 현재 구현은 H2 테스트 DB를 사용한다.
- fixture 결과는 샘플 ID와 텍스트 해시 기반으로 매핑한다.
- 상세 스키마는 [fixture-data-model.md](fixture-data-model.md)를 기준으로 한다.

## 6. 2차 MVP 확장 포인트

- `FixtureDiagnosisProvider`를 `GeminiDiagnosisProvider`로 교체
- JD 입력/링크 수집 추가
- 이력서와 JD 비교 분석 추가
