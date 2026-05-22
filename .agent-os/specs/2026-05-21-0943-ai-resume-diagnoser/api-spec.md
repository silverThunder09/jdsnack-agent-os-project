# API 명세서

> 프로젝트: JDSnack — 1차 MVP 서비스 뼈대  
> 버전: v1.0.0  
> 최종 수정일: 2026-05-21  
> 핵심 결정: 1차 MVP에서는 사용자 인증 정보 입력과 서버 외부 AI 연동을 모두 제외한다.

## 1. API 공통 규격

### 1.1 기본 URL

```text
/api
```

단일 JAR 배포 구조를 목표로 하므로 프론트엔드(`/`)와 API(`/api/**`)는 같은 오리진에서 서비스한다.

### 1.2 공통 응답 구조

#### 성공 응답

```json
{
  "success": true,
  "data": {},
  "timestamp": "2026-05-21T09:30:00.000+09:00"
}
```

#### 실패 응답

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "사용자에게 표시할 에러 메시지"
  },
  "timestamp": "2026-05-21T09:30:00.000+09:00"
}
```

### 1.3 공통 에러 코드

| HTTP 상태 코드 | 에러 코드 | 설명 | 사용자 메시지 |
|---|---|---|---|
| `400` | `EMPTY_RESUME` | 이력서 텍스트가 비어 있음 | `이력서 내용을 입력해주세요.` |
| `400` | `TEXT_TOO_SHORT` | 이력서 텍스트가 50자 미만 | `이력서 내용이 너무 짧습니다. 최소 50자 이상 입력해주세요.` |
| `400` | `TEXT_TOO_LONG` | 이력서 텍스트가 10,000자 초과 | `이력서 내용이 너무 깁니다. 10,000자 이내로 입력해주세요.` |
| `501` | `AI_ANALYSIS_NOT_ENABLED` | 1차 MVP에서 AI 분석 미연동 | `AI 분석 기능은 준비 중입니다. 현재는 이력서 입력 검증만 가능합니다.` |
| `404` | `NOT_FOUND` | 등록되지 않은 경로 요청 | `요청한 경로를 찾을 수 없습니다.` |
| `500` | `INTERNAL_ERROR` | 서버 내부 오류 | `서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.` |

## 2. `POST /api/diagnose`

### 2.1 개요

| 항목 | 값 |
|---|---|
| 엔드포인트 | `POST /api/diagnose` |
| 설명 | 이력서 텍스트 입력값을 검증하고, 1차 MVP에서는 AI 분석 준비중 응답을 반환한다. |
| 인증 | 없음 |
| 외부 AI 호출 | 없음 |

### 2.2 Request

```http
POST /api/diagnose HTTP/1.1
Content-Type: application/json; charset=UTF-8
Accept: application/json
```

```json
{
  "resumeText": "string"
}
```

| 필드 | 타입 | 필수 | 제약 조건 | 설명 |
|---|---|---|---|---|
| `resumeText` | `string` | 예 | 50자 이상 10,000자 이하 | 사용자가 붙여넣은 이력서 텍스트 |

검증 규칙:

- `resumeText`가 누락, `null`, 빈 문자열, 공백 문자만 있는 값이면 `EMPTY_RESUME`으로 처리한다.
- 길이 검증은 앞뒤 공백을 제거한 뒤의 텍스트 기준으로 수행한다.
- 정확히 50자와 정확히 10,000자는 유효한 입력으로 본다.

### 2.3 정상 입력이지만 AI 미연동 — `501 Not Implemented`

50자 이상 10,000자 이하의 입력은 검증을 통과한다. 다만 1차 MVP에서는 AI 분석을 수행하지 않으므로 아래 응답을 반환한다.

```json
{
  "success": false,
  "error": {
    "code": "AI_ANALYSIS_NOT_ENABLED",
    "message": "AI 분석 기능은 준비 중입니다. 현재는 이력서 입력 검증만 가능합니다."
  },
  "timestamp": "2026-05-21T09:35:12.345+09:00"
}
```

### 2.4 검증 실패 응답

#### 빈 입력 — `400 Bad Request`

```json
{
  "success": false,
  "error": {
    "code": "EMPTY_RESUME",
    "message": "이력서 내용을 입력해주세요."
  },
  "timestamp": "2026-05-21T09:35:12.345+09:00"
}
```

#### 50자 미만 — `400 Bad Request`

```json
{
  "success": false,
  "error": {
    "code": "TEXT_TOO_SHORT",
    "message": "이력서 내용이 너무 짧습니다. 최소 50자 이상 입력해주세요."
  },
  "timestamp": "2026-05-21T09:35:12.345+09:00"
}
```

#### 10,000자 초과 — `400 Bad Request`

```json
{
  "success": false,
  "error": {
    "code": "TEXT_TOO_LONG",
    "message": "이력서 내용이 너무 깁니다. 10,000자 이내로 입력해주세요."
  },
  "timestamp": "2026-05-21T09:35:12.345+09:00"
}
```

### 2.5 Java DTO

```java
public record DiagnoseRequest(
    String resumeText
) {}
```

`EMPTY_RESUME`, `TEXT_TOO_SHORT`, `TEXT_TOO_LONG`을 구분해야 하므로 Bean Validation 기본 메시지에만 의존하지 않고 Validation Service 또는 공통 예외 매핑에서 에러 코드를 정규화한다.

```java
public record ApiResponse<T>(
    boolean success,
    T data,
    ErrorDetail error,
    String timestamp
) {}

public record ErrorDetail(
    String code,
    String message
) {}
```

### 2.6 처리 흐름

```text
클라이언트 요청
    |
    v
[1] resumeText가 null 또는 빈 문자열? -> 400 EMPTY_RESUME
    |
    v
[2] resumeText.length() < 50? -> 400 TEXT_TOO_SHORT
    |
    v
[3] resumeText.length() > 10000? -> 400 TEXT_TOO_LONG
    |
    v
[4] 검증 통과 -> 501 AI_ANALYSIS_NOT_ENABLED
```

## 3. `GET /`

### 3.1 개요

| 항목 | 값 |
|---|---|
| 엔드포인트 | `GET /` |
| 설명 | 브라우저에서 서비스 기동 여부를 확인하기 위한 기본 엔트리 응답 |
| 인증 | 없음 |

### 3.2 Response — `200 OK`

```json
{
  "success": true,
  "data": {
    "service": "JDSnack",
    "status": "RUNNING",
    "healthPath": "/api/health",
    "diagnosePath": "/api/diagnose"
  },
  "timestamp": "2026-05-22T11:41:00.000+09:00"
}
```

## 4. `GET /api/health`

### 4.1 개요

| 항목 | 값 |
|---|---|
| 엔드포인트 | `GET /api/health` |
| 설명 | 서버 상태 확인용 API |
| 인증 | 없음 |

### 4.2 Response — `200 OK`

```json
{
  "success": true,
  "data": {
    "status": "UP",
    "service": "JDSnack",
    "version": "1.0.0"
  },
  "timestamp": "2026-05-21T09:35:12.345+09:00"
}
```

## 5. 미등록 경로 응답

등록되지 않은 경로는 `404 NOT_FOUND`로 응답한다.

```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "요청한 경로를 찾을 수 없습니다."
  },
  "timestamp": "2026-05-22T11:41:00.000+09:00"
}
```

## 6. 2차 MVP 확장 예정

1차 MVP에서는 외부 AI 호출을 하지 않는다. 아래 항목은 2차 MVP에서 별도 `REQ`, `AC`, `TC`를 추가한 뒤 구현한다.

- 서버 환경변수 기반 외부 AI 연동
- `score`, `readabilityFeedback`, `contributionFeedback`, `summary` 응답 생성
- 외부 AI 실패, 타임아웃, 재시도 정책
- 분석 결과 저장과 히스토리 조회
