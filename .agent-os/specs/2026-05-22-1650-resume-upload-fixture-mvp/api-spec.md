# API 명세서

> 프로젝트: JDSnack — 1.5차 MVP 이력서 업로드 + fixture 분석
> 핵심 결정: 실제 외부 AI 호출 대신 fixture 분석 결과를 반환한다.

## 1. 공통 응답

성공 응답:

```json
{
  "success": true,
  "data": {},
  "timestamp": "2026-05-22T16:00:00.000+09:00"
}
```

실패 응답:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "사용자에게 표시할 에러 메시지"
  },
  "timestamp": "2026-05-22T16:00:00.000+09:00"
}
```

## 2. 추가 에러 코드

| HTTP 상태 코드 | 에러 코드 | 설명 |
|---|---|---|
| `400` | `UNSUPPORTED_FILE_TYPE` | PDF, DOCX 외 파일 형식 |
| `400` | `FILE_TEXT_EXTRACTION_FAILED` | 파일에서 텍스트를 추출하지 못함 |
| `404` | `FIXTURE_NOT_FOUND` | fixture 결과 매핑 없음 |

## 3. `POST /api/diagnose`

### 3.1 개요

- 기존 1차 MVP의 텍스트 입력 API를 유지한다.
- 기본 운영 모드는 `stub`다.
- 운영 모드가 fixture일 때는 `501 AI_ANALYSIS_NOT_ENABLED` 대신 fixture 결과를 반환한다.

### 3.2 Request

```json
{
  "resumeText": "string"
}
```

### 3.3 Response — fixture 성공

```json
{
  "success": true,
  "data": {
    "score": 78,
    "summary": "백엔드 중심 경험은 분명하지만 성과 수치가 더 필요합니다.",
    "strengths": [
      "Spring Boot API 구현 경험이 보입니다."
    ],
    "improvements": [
      "프로젝트 결과를 수치로 보강해 주세요."
    ]
  },
  "timestamp": "2026-05-22T16:00:00.000+09:00"
}
```

## 4. `POST /api/diagnose/file`

### 4.1 개요

- PDF 또는 DOCX 파일을 업로드해 텍스트를 추출한 뒤 fixture 분석 결과를 반환한다.

### 4.2 Request

```http
POST /api/diagnose/file
Content-Type: multipart/form-data
```

Form fields:

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `resumeFile` | file | 예 | PDF 또는 DOCX 이력서 파일 |

### 4.3 Response — fixture 성공

- 응답 구조는 `POST /api/diagnose`의 fixture 성공 응답과 동일하다.

### 4.4 실패 응답

- 지원하지 않는 형식: `400 UNSUPPORTED_FILE_TYPE`
- 텍스트 추출 실패: `400 FILE_TEXT_EXTRACTION_FAILED`
- fixture 매핑 없음: `404 FIXTURE_NOT_FOUND`

## 5. fixture 결과 구조

```json
{
  "score": 78,
  "summary": "string",
  "strengths": ["string"],
  "improvements": ["string"]
}
```

- 최소 응답 구조만 유지하고, 내부 fixture 저장 구조는 [fixture-data-model.md](fixture-data-model.md)에 정의한다.
- 구현 시 입력 매핑과 분석 결과 본문은 분리 저장한다.

## 6. 구현 메모

- `DiagnosisProvider` 인터페이스를 두고 `StubDiagnosisProvider`, `FixtureDiagnosisProvider`를 분리한다.
- 파일 업로드 API는 `multipart/form-data`를 사용한다.
- PDF/DOCX 텍스트 추출은 별도 `ResumeExtractionService` 계층에서 처리한다.
- fixture 저장소는 H2 테스트 DB와 `JdbcTemplate` 기반 조회로 구현한다.
