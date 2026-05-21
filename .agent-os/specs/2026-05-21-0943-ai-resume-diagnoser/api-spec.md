# API 명세서

> **프로젝트**: JDSnack — AI 이력서 진단 서비스  
> **버전**: v1.0.0 (MVP)  
> **최종 수정일**: 2026-05-21  
> **배포 형태**: Spring Boot 단일 JAR (Frontend 정적 리소스 포함)

---

## 목차

1. [API 공통 규격](#1-api-공통-규격)
2. [POST /api/diagnose — 이력서 진단 API](#2-post-apidiagnose--이력서-진단-api)
3. [GET /api/health — 헬스체크 API](#3-get-apihealth--헬스체크-api)
4. [Gemini API 연동 스펙](#4-gemini-api-연동-스펙)

---

## 1. API 공통 규격

### 1.1 기본 URL

```
/api
```

- 단일 JAR 배포 구조이므로 프론트엔드(`/`)와 API(`/api/**`)가 동일한 오리진에서 서비스됩니다.
- 프로덕션 배포 시 별도의 도메인/포트 분리가 없으므로 Base URL은 상대 경로로 사용합니다.

### 1.2 콘텐츠 타입

| 항목 | 값 |
|---|---|
| 요청 Content-Type | `application/json; charset=UTF-8` |
| 응답 Content-Type | `application/json; charset=UTF-8` |
| Accept | `application/json` |

- 모든 요청/응답 본문은 **UTF-8 인코딩 JSON** 형식입니다.
- `multipart/form-data` 등 다른 형식은 MVP에서 지원하지 않습니다.

### 1.3 공통 응답 구조 (성공 응답 래퍼 패턴)

모든 API 응답은 아래의 일관된 **공통 래퍼 구조**를 따릅니다.

#### 성공 응답

```json
{
  "success": true,
  "data": {
    // 각 API별 응답 데이터
  },
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

#### Java 응답 래퍼 클래스

```java
public record ApiResponse<T>(
    boolean success,
    T data,
    ErrorDetail error,
    String timestamp
) {
    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(true, data, null, Instant.now().toString());
    }

    public static <T> ApiResponse<T> fail(String code, String message) {
        return new ApiResponse<>(false, null, new ErrorDetail(code, message), Instant.now().toString());
    }
}

public record ErrorDetail(
    String code,
    String message
) {}
```

### 1.4 공통 에러 코드 목록

| HTTP 상태 코드 | 에러 코드 | 설명 | 사용자 메시지 예시 |
|---|---|---|---|
| `400` | `BAD_REQUEST` | 잘못된 요청 형식 | "요청 형식이 올바르지 않습니다." |
| `400` | `EMPTY_RESUME` | 이력서 텍스트가 비어있음 | "이력서 내용을 입력해주세요." |
| `400` | `TEXT_TOO_SHORT` | 이력서 텍스트가 50자 미만 | "이력서 내용이 너무 짧습니다. 최소 50자 이상 입력해주세요." |
| `400` | `TEXT_TOO_LONG` | 이력서 텍스트가 10,000자 초과 | "이력서 내용이 너무 깁니다. 10,000자 이내로 입력해주세요." |
| `401` | `INVALID_API_KEY` | Gemini API 키 인증 실패 | "서비스 인증에 실패했습니다. 관리자에게 문의해주세요." |
| `429` | `RATE_LIMIT_EXCEEDED` | 요청 횟수 제한 초과 | "요청이 너무 많습니다. 잠시 후 다시 시도해주세요." |
| `500` | `AI_SERVICE_ERROR` | Gemini API 호출 실패 | "AI 분석 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요." |
| `500` | `INTERNAL_ERROR` | 서버 내부 오류 | "서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요." |
| `503` | `SERVICE_UNAVAILABLE` | 외부 서비스 일시 불가 | "서비스가 일시적으로 이용 불가합니다. 잠시 후 다시 시도해주세요." |

### 1.5 CORS 설정

> [!NOTE]
> 단일 JAR 배포 구조에서는 프론트엔드와 백엔드가 동일 오리진이므로 CORS 이슈가 발생하지 않습니다.
> 다만, 로컬 개발 시 Vite 개발 서버(포트 5173)와 Spring Boot(포트 8080)가 다른 포트에서 실행되므로 개발 편의를 위해 CORS를 설정합니다.

```java
@Configuration
public class CorsConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOrigins(
                    "http://localhost:5173",  // Vite 개발 서버
                    "http://localhost:8080"   // Spring Boot 서버
                )
                .allowedMethods("GET", "POST", "OPTIONS")
                .allowedHeaders("Content-Type", "Accept")
                .allowCredentials(false)
                .maxAge(3600);
    }
}
```

#### 프로덕션 환경

프로덕션 배포 시에는 Vite 빌드 산출물이 Spring Boot의 `src/main/resources/static/` 에 포함되므로 별도의 CORS 설정이 불필요합니다. 환경별 프로파일을 통해 CORS를 비활성화할 수 있습니다.

```yaml
# application-prod.yml
cors:
  enabled: false
```

### 1.6 HTTP 메서드 규칙

| 메서드 | 용도 | 멱등성 |
|---|---|---|
| `GET` | 리소스 조회 (헬스체크 등) | 멱등 |
| `POST` | 이력서 진단 요청 | 비멱등 |
| `OPTIONS` | CORS Preflight | 멱등 |

---

## 2. POST /api/diagnose — 이력서 진단 API

### 2.1 개요

| 항목 | 값 |
|---|---|
| **엔드포인트** | `POST /api/diagnose` |
| **설명** | 사용자가 입력한 이력서 텍스트를 Google Gemini AI에 전달하여 분석 결과(점수, 가독성 피드백, 프로젝트 기여도 피드백, 종합 요약)를 반환합니다. |
| **인증** | 불필요 (MVP) |
| **Rate Limit** | IP 기준 분당 10회 |

### 2.2 Request

#### HTTP 헤더

```
POST /api/diagnose HTTP/1.1
Content-Type: application/json; charset=UTF-8
Accept: application/json
```

#### 요청 본문

```json
{
  "resumeText": "string (required)"
}
```

| 필드 | 타입 | 필수 | 제약 조건 | 설명 |
|---|---|---|---|---|
| `resumeText` | `string` | ✅ | 최소 50자, 최대 10,000자 | 사용자가 붙여넣기한 이력서 원문 텍스트 |

#### Java 요청 DTO

```java
public record DiagnoseRequest(
    @NotBlank(message = "이력서 내용을 입력해주세요.")
    @Size(min = 50, max = 10000, message = "이력서는 50자 이상 10,000자 이하로 입력해주세요.")
    String resumeText
) {}
```

#### 요청 예시

```json
{
  "resumeText": "홍길동\n서울특별시 강남구\nhong@email.com\n\n[경력사항]\n- ABC 테크 주식회사 (2023.03 ~ 현재)\n  백엔드 개발자\n  - Spring Boot 기반 주문 관리 시스템 개발\n  - REST API 설계 및 구현 (일 평균 5만 건 처리)\n  - JPA/QueryDSL을 활용한 데이터 액세스 레이어 최적화\n  - Redis 캐시 도입으로 응답 속도 40% 개선\n\n[프로젝트]\n1. 실시간 재고 관리 시스템\n   - 역할: 백엔드 리드 (팀원 3명)\n   - 기술 스택: Java 17, Spring Boot 3.x, PostgreSQL, Redis\n   - WebSocket 기반 실시간 재고 동기화 구현\n   - 동시성 이슈 해결을 위한 분산 락 적용\n\n[기술 스택]\nJava, Spring Boot, JPA, Redis, PostgreSQL, Docker, AWS"
}
```

### 2.3 Response — 성공 (200 OK)

```json
{
  "success": true,
  "data": {
    "score": 78,
    "readabilityFeedback": [
      "경력사항에 구체적인 성과 지표(5만 건, 40%)를 포함하고 있어 좋습니다.",
      "연락처 정보에 LinkedIn 또는 GitHub 프로필 링크를 추가하면 더 전문적인 인상을 줄 수 있습니다.",
      "기술 스택 섹션을 카테고리별(언어, 프레임워크, 인프라)로 분류하면 가독성이 향상됩니다.",
      "경력 기간 표기를 '2023.03 ~ 현재' 대신 '2023년 3월 ~ 현재 (2년 3개월)'처럼 기간을 병기하면 좋습니다."
    ],
    "contributionFeedback": [
      "프로젝트에서 '백엔드 리드'라는 역할이 명시되어 있으나, 구체적으로 어떤 의사결정을 주도했는지 서술이 필요합니다.",
      "'분산 락 적용'에 대해 어떤 문제를 해결했고 그 효과가 무엇이었는지 정량적 수치를 추가해보세요.",
      "팀 내 코드 리뷰, 기술 공유 등 협업 기여도를 보여줄 수 있는 내용을 추가하면 좋겠습니다."
    ],
    "summary": "전반적으로 기술적 역량이 잘 드러나는 이력서입니다. 특히 성과 지표를 활용한 정량적 표현이 강점입니다. 다만, 프로젝트 기여도 섹션에서 본인의 구체적인 역할과 의사결정 과정을 더 상세히 기술하면 78점에서 90점 이상으로 향상될 수 있습니다."
  },
  "timestamp": "2026-05-21T09:35:12.345+09:00"
}
```

#### Response 필드 상세

| 필드 | 타입 | 설명 |
|---|---|---|
| `score` | `number` | 이력서 종합 점수 (0~100점) |
| `readabilityFeedback` | `string[]` | 가독성 관련 피드백 목록 (형식, 구조, 표현 등) |
| `contributionFeedback` | `string[]` | 프로젝트 기여도 관련 피드백 목록 (역할, 성과, 임팩트 등) |
| `summary` | `string` | AI가 생성한 종합 평가 요약문 |

#### Java 응답 DTO

```java
public record DiagnoseResponse(
    int score,
    List<String> readabilityFeedback,
    List<String> contributionFeedback,
    String summary
) {}
```

### 2.4 Response — 실패

모든 실패 응답은 공통 에러 응답 구조를 따릅니다.

#### 2.4.1 이력서 텍스트 누락 — `400 Bad Request`

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

#### 2.4.2 이력서 텍스트 너무 짧음 — `400 Bad Request`

```json
{
  "success": false,
  "error": {
    "code": "TEXT_TOO_SHORT",
    "message": "이력서 내용이 너무 짧습니다. 최소 50자 이상 입력해주세요. (현재: 23자)"
  },
  "timestamp": "2026-05-21T09:35:12.345+09:00"
}
```

#### 2.4.3 이력서 텍스트 너무 김 — `400 Bad Request`

```json
{
  "success": false,
  "error": {
    "code": "TEXT_TOO_LONG",
    "message": "이력서 내용이 너무 깁니다. 10,000자 이내로 입력해주세요. (현재: 12,340자)"
  },
  "timestamp": "2026-05-21T09:35:12.345+09:00"
}
```

#### 2.4.4 AI 서비스 오류 — `500 Internal Server Error`

```json
{
  "success": false,
  "error": {
    "code": "AI_SERVICE_ERROR",
    "message": "AI 분석 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
  },
  "timestamp": "2026-05-21T09:35:12.345+09:00"
}
```

#### 2.4.5 API 키 인증 실패 — `401 Unauthorized`

```json
{
  "success": false,
  "error": {
    "code": "INVALID_API_KEY",
    "message": "서비스 인증에 실패했습니다. 관리자에게 문의해주세요."
  },
  "timestamp": "2026-05-21T09:35:12.345+09:00"
}
```

#### 2.4.6 요청 횟수 제한 초과 — `429 Too Many Requests`

```json
{
  "success": false,
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "요청이 너무 많습니다. 1분 후 다시 시도해주세요."
  },
  "timestamp": "2026-05-21T09:35:12.345+09:00"
}
```

### 2.5 Rate Limiting 정책

| 항목 | 값 |
|---|---|
| **제한 기준** | 클라이언트 IP 주소 |
| **허용 횟수** | 분당 10회 |
| **윈도우 방식** | 슬라이딩 윈도우 (Sliding Window) |
| **초과 시 응답** | `429 Too Many Requests` |
| **구현 방식** | 인메모리 `ConcurrentHashMap` 기반 (MVP) |

> [!TIP]
> MVP 단계에서는 인메모리 방식으로 구현하여 단일 서버 환경에서 동작합니다.
> 추후 스케일 아웃 시 Redis 기반의 분산 Rate Limiter로 전환할 수 있습니다.

#### Rate Limiter 구현 참고 코드

```java
@Component
public class RateLimiter {

    private static final int MAX_REQUESTS_PER_MINUTE = 10;
    private final ConcurrentHashMap<String, Deque<Instant>> requestLog = new ConcurrentHashMap<>();

    /**
     * 요청 허용 여부를 판단합니다.
     * @param clientIp 클라이언트 IP 주소
     * @return true이면 허용, false이면 제한 초과
     */
    public boolean isAllowed(String clientIp) {
        Instant now = Instant.now();
        Instant windowStart = now.minus(1, ChronoUnit.MINUTES);

        Deque<Instant> timestamps = requestLog.computeIfAbsent(clientIp, k -> new ConcurrentLinkedDeque<>());

        // 윈도우 밖의 오래된 기록 제거
        while (!timestamps.isEmpty() && timestamps.peekFirst().isBefore(windowStart)) {
            timestamps.pollFirst();
        }

        if (timestamps.size() >= MAX_REQUESTS_PER_MINUTE) {
            return false;
        }

        timestamps.addLast(now);
        return true;
    }
}
```

### 2.6 Controller 구현 참고 코드

```java
@RestController
@RequestMapping("/api")
public class DiagnoseController {

    private final DiagnoseService diagnoseService;
    private final RateLimiter rateLimiter;

    public DiagnoseController(DiagnoseService diagnoseService, RateLimiter rateLimiter) {
        this.diagnoseService = diagnoseService;
        this.rateLimiter = rateLimiter;
    }

    @PostMapping("/diagnose")
    public ResponseEntity<ApiResponse<DiagnoseResponse>> diagnose(
            @Valid @RequestBody DiagnoseRequest request,
            HttpServletRequest httpRequest
    ) {
        String clientIp = httpRequest.getRemoteAddr();

        if (!rateLimiter.isAllowed(clientIp)) {
            return ResponseEntity.status(429)
                .body(ApiResponse.fail("RATE_LIMIT_EXCEEDED", "요청이 너무 많습니다. 1분 후 다시 시도해주세요."));
        }

        DiagnoseResponse result = diagnoseService.diagnose(request.resumeText());
        return ResponseEntity.ok(ApiResponse.ok(result));
    }
}
```

### 2.7 유효성 검증 흐름

```
클라이언트 요청
    │
    ▼
[1] resumeText가 null 또는 빈 문자열? ──YES──▶ 400 EMPTY_RESUME
    │ NO
    ▼
[2] resumeText.length() < 50?  ──YES──▶ 400 TEXT_TOO_SHORT
    │ NO
    ▼
[3] resumeText.length() > 10000? ──YES──▶ 400 TEXT_TOO_LONG
    │ NO
    ▼
[4] Rate Limit 초과?  ──YES──▶ 429 RATE_LIMIT_EXCEEDED
    │ NO
    ▼
[5] Gemini API 호출
    │
    ├── API 키 인증 실패  ──▶ 401 INVALID_API_KEY
    ├── 타임아웃/호출 실패 ──▶ 500 AI_SERVICE_ERROR
    └── 성공 ──▶ 200 OK + 진단 결과
```

### 2.8 예외 처리 (Global Exception Handler)

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<Void>> handleValidation(MethodArgumentNotValidException ex) {
        String field = ex.getBindingResult().getFieldErrors().get(0).getField();
        String message = ex.getBindingResult().getFieldErrors().get(0).getDefaultMessage();

        String code = switch (field) {
            case "resumeText" -> {
                if (message.contains("비어")) yield "EMPTY_RESUME";
                else if (message.contains("짧")) yield "TEXT_TOO_SHORT";
                else yield "TEXT_TOO_LONG";
            }
            default -> "BAD_REQUEST";
        };

        return ResponseEntity.badRequest()
            .body(ApiResponse.fail(code, message));
    }

    @ExceptionHandler(GeminiApiException.class)
    public ResponseEntity<ApiResponse<Void>> handleGeminiError(GeminiApiException ex) {
        if (ex.isAuthError()) {
            return ResponseEntity.status(401)
                .body(ApiResponse.fail("INVALID_API_KEY", "서비스 인증에 실패했습니다. 관리자에게 문의해주세요."));
        }
        return ResponseEntity.status(500)
            .body(ApiResponse.fail("AI_SERVICE_ERROR", "AI 분석 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleGeneral(Exception ex) {
        return ResponseEntity.status(500)
            .body(ApiResponse.fail("INTERNAL_ERROR", "서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요."));
    }
}
```

---

## 3. GET /api/health — 헬스체크 API

### 3.1 개요

| 항목 | 값 |
|---|---|
| **엔드포인트** | `GET /api/health` |
| **설명** | 서버의 가동 상태를 확인합니다. 배포 환경(AWS Elastic Beanstalk 등)의 헬스체크 엔드포인트로 사용됩니다. |
| **인증** | 불필요 |
| **Rate Limit** | 없음 |

### 3.2 Request

```
GET /api/health HTTP/1.1
Accept: application/json
```

- 요청 본문: 없음
- Query Parameter: 없음

### 3.3 Response — 성공 (200 OK)

```json
{
  "success": true,
  "data": {
    "status": "UP",
    "timestamp": "2026-05-21T09:30:00.000+09:00"
  },
  "timestamp": "2026-05-21T09:30:00.000+09:00"
}
```

| 필드 | 타입 | 설명 |
|---|---|---|
| `status` | `string` | 서버 상태. 정상이면 `"UP"` |
| `timestamp` | `string` | 응답 생성 시각 (ISO 8601 형식) |

### 3.4 Controller 구현 참고 코드

```java
@RestController
@RequestMapping("/api")
public class HealthController {

    @GetMapping("/health")
    public ResponseEntity<ApiResponse<HealthResponse>> health() {
        HealthResponse response = new HealthResponse("UP", Instant.now().toString());
        return ResponseEntity.ok(ApiResponse.ok(response));
    }
}

public record HealthResponse(
    String status,
    String timestamp
) {}
```

### 3.5 활용 시나리오

| 사용처 | 설명 |
|---|---|
| AWS Elastic Beanstalk | 인스턴스 헬스체크 경로로 `/api/health` 설정 |
| 프론트엔드 초기 로딩 | 앱 진입 시 서버 가용성 확인 용도 (선택적) |
| 모니터링 도구 | 외부 모니터링 서비스에서 주기적 상태 확인 |

---

## 4. Gemini API 연동 스펙

### 4.1 사용 모델 및 설정

| 항목 | 값 | 비고 |
|---|---|---|
| **모델** | `gemini-2.0-flash` | 빠른 응답 속도, MVP에 적합 |
| **대체 모델** | `gemini-1.5-pro` | 정밀도 필요 시 전환 가능 |
| **API 엔드포인트** | `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent` | Google AI Studio 기준 |
| **인증 방식** | API Key (쿼리 파라미터 `key`) | `application.yml`에서 환경변수로 주입 |
| **타임아웃** | 30초 | 연결 타임아웃 5초, 읽기 타임아웃 30초 |
| **재시도 정책** | 최대 2회 (총 3회 시도) | 5xx 에러 및 타임아웃 시에만 재시도 |

### 4.2 API 키 관리

```yaml
# application.yml
gemini:
  api:
    key: ${GEMINI_API_KEY}         # 환경변수에서 주입 (절대 하드코딩 금지)
    model: gemini-2.0-flash
    timeout: 30000                  # 밀리초
    max-retries: 2
    max-output-tokens: 2048
    temperature: 0.3
```

> [!CAUTION]
> API 키는 절대로 소스코드에 하드코딩하지 마세요.
> 반드시 환경변수(`GEMINI_API_KEY`) 또는 AWS Secrets Manager를 통해 주입합니다.
> `.env` 파일은 `.gitignore`에 반드시 포함합니다.

### 4.3 프롬프트 구조 상세 설계

Gemini API에 전달하는 프롬프트는 **System Prompt**와 **User Prompt**로 구성됩니다.

#### 4.3.1 System Prompt (시스템 지시문)

```text
당신은 10년 이상의 경력을 가진 전문 이력서 컨설턴트입니다.
IT/소프트웨어 개발 분야의 이력서를 전문적으로 분석하고 피드백을 제공합니다.

## 역할
- 이력서의 전체적인 완성도를 100점 만점으로 평가합니다.
- 가독성(형식, 구조, 표현 방식) 측면의 구체적인 피드백을 제공합니다.
- 프로젝트 기여도(역할, 성과, 임팩트) 측면의 구체적인 피드백을 제공합니다.
- 종합적인 개선 방향을 요약합니다.

## 평가 기준
### 점수 (score: 0~100)
- 90~100: 즉시 제출 가능한 수준의 우수한 이력서
- 70~89: 약간의 보완으로 크게 개선 가능한 이력서
- 50~69: 구조적 개선이 필요한 이력서
- 0~49: 전면적인 재작성이 권장되는 이력서

### 가독성 피드백 (readabilityFeedback)
- 섹션 구분의 명확성
- 글머리 기호 및 들여쓰기 일관성
- 날짜/기간 표기 통일성
- 핵심 정보의 가시성
- 불필요한 정보의 포함 여부

### 프로젝트 기여도 피드백 (contributionFeedback)
- 개인 역할과 책임의 명확한 서술 여부
- 정량적 성과 지표(숫자, 퍼센트) 포함 여부
- 기술적 의사결정 과정의 서술 여부
- 팀 내 기여도와 협업 방식의 표현 여부
- STAR(Situation-Task-Action-Result) 구조 활용 여부

## 응답 형식
반드시 아래 JSON 형식으로만 응답하세요. 다른 텍스트를 추가하지 마세요.

```json
{
  "score": <0-100 사이의 정수>,
  "readabilityFeedback": ["피드백1", "피드백2", "피드백3"],
  "contributionFeedback": ["피드백1", "피드백2", "피드백3"],
  "summary": "종합 평가 요약문 (2~3문장)"
}
```

## 주의사항
- 각 피드백 항목은 구체적이고 실행 가능한 조언이어야 합니다.
- 긍정적인 점과 개선이 필요한 점을 균형 있게 포함하세요.
- readabilityFeedback은 최소 2개, 최대 5개 항목을 제공하세요.
- contributionFeedback은 최소 2개, 최대 5개 항목을 제공하세요.
- summary는 2~3문장으로 핵심만 간결하게 작성하세요.
- 반드시 유효한 JSON 형식으로만 응답하세요.
```

#### 4.3.2 User Prompt (사용자 입력)

```text
다음 이력서를 분석하고 피드백을 제공해주세요.

---
{resumeText}
---
```

- `{resumeText}`는 사용자가 입력한 이력서 텍스트로 치환됩니다.
- 이력서 텍스트는 `---` 구분선으로 감싸서 프롬프트 인젝션을 최소화합니다.

### 4.4 Gemini API 호출 구조

#### 4.4.1 HTTP 요청 형식

```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={API_KEY}
Content-Type: application/json
```

#### 4.4.2 요청 본문

```json
{
  "systemInstruction": {
    "parts": [
      {
        "text": "<System Prompt 전문>"
      }
    ]
  },
  "contents": [
    {
      "parts": [
        {
          "text": "다음 이력서를 분석하고 피드백을 제공해주세요.\n\n---\n{resumeText}\n---"
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.3,
    "maxOutputTokens": 2048,
    "responseMimeType": "application/json"
  }
}
```

#### 4.4.3 파라미터 상세

| 파라미터 | 값 | 설명 |
|---|---|---|
| `temperature` | `0.3` | 낮은 값으로 설정하여 일관성 있는 평가 결과를 보장. 0에 가까울수록 결정적, 1에 가까울수록 창의적. |
| `maxOutputTokens` | `2048` | 충분한 피드백 생성을 위해 2048 토큰 설정. 평균 응답은 약 500~1000 토큰. |
| `responseMimeType` | `"application/json"` | Gemini API의 JSON 모드를 활성화하여 유효한 JSON 응답을 강제합니다. |

### 4.5 기대 응답 JSON 스키마

Gemini API가 반환해야 하는 JSON의 상세 스키마입니다.

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["score", "readabilityFeedback", "contributionFeedback", "summary"],
  "properties": {
    "score": {
      "type": "integer",
      "minimum": 0,
      "maximum": 100,
      "description": "이력서 종합 점수 (0~100)"
    },
    "readabilityFeedback": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "minItems": 2,
      "maxItems": 5,
      "description": "가독성 관련 피드백 목록"
    },
    "contributionFeedback": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "minItems": 2,
      "maxItems": 5,
      "description": "프로젝트 기여도 관련 피드백 목록"
    },
    "summary": {
      "type": "string",
      "maxLength": 500,
      "description": "종합 평가 요약문"
    }
  },
  "additionalProperties": false
}
```

### 4.6 Gemini 서비스 구현 참고 코드

```java
@Service
public class GeminiService {

    private static final Logger log = LoggerFactory.getLogger(GeminiService.class);

    private final RestClient restClient;
    private final String apiKey;
    private final String model;
    private final int maxRetries;

    public GeminiService(
        @Value("${gemini.api.key}") String apiKey,
        @Value("${gemini.api.model}") String model,
        @Value("${gemini.api.max-retries}") int maxRetries,
        @Value("${gemini.api.timeout}") int timeout
    ) {
        this.apiKey = apiKey;
        this.model = model;
        this.maxRetries = maxRetries;
        this.restClient = RestClient.builder()
            .baseUrl("https://generativelanguage.googleapis.com/v1beta")
            .requestFactory(createRequestFactory(timeout))
            .build();
    }

    /**
     * 이력서 텍스트를 Gemini API로 분석합니다.
     *
     * @param resumeText 분석할 이력서 텍스트
     * @return 진단 결과
     * @throws GeminiApiException API 호출 실패 시
     */
    public DiagnoseResponse analyze(String resumeText) {
        String requestBody = buildRequestBody(resumeText);

        for (int attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                String response = restClient.post()
                    .uri("/models/{model}:generateContent?key={key}", model, apiKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(requestBody)
                    .retrieve()
                    .body(String.class);

                return parseResponse(response);

            } catch (HttpClientErrorException.Unauthorized e) {
                // 인증 실패는 재시도하지 않음
                throw new GeminiApiException("API 키 인증 실패", true);
            } catch (Exception e) {
                log.warn("Gemini API 호출 실패 (시도 {}/{}): {}", attempt + 1, maxRetries + 1, e.getMessage());
                if (attempt == maxRetries) {
                    throw new GeminiApiException("AI 서비스 호출 실패: " + e.getMessage(), false);
                }
                // 재시도 전 대기 (지수 백오프)
                sleep(1000L * (attempt + 1));
            }
        }

        throw new GeminiApiException("최대 재시도 횟수 초과", false);
    }

    private String buildRequestBody(String resumeText) {
        // System Prompt + User Prompt를 조합하여 Gemini API 요청 본문을 구성합니다.
        // 실제 구현 시 ObjectMapper를 사용하여 JSON을 생성합니다.
        // ... (상세 구현 생략)
    }

    private DiagnoseResponse parseResponse(String rawResponse) {
        // Gemini API 응답에서 JSON 텍스트를 추출하고 DiagnoseResponse로 변환합니다.
        // candidates[0].content.parts[0].text에서 JSON을 파싱합니다.
        // ... (상세 구현 생략)
    }

    private ClientHttpRequestFactory createRequestFactory(int timeout) {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(Duration.ofSeconds(5));
        factory.setReadTimeout(Duration.ofMillis(timeout));
        return factory;
    }

    private void sleep(long millis) {
        try {
            Thread.sleep(millis);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
```

### 4.7 Gemini API 응답 파싱

Gemini API의 원본 응답 구조에서 실제 텍스트를 추출하는 방법입니다.

#### 원본 응답 구조

```json
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "{\"score\":78,\"readabilityFeedback\":[...],\"contributionFeedback\":[...],\"summary\":\"...\"}"
          }
        ],
        "role": "model"
      },
      "finishReason": "STOP",
      "safetyRatings": [...]
    }
  ],
  "usageMetadata": {
    "promptTokenCount": 850,
    "candidatesTokenCount": 420,
    "totalTokenCount": 1270
  }
}
```

#### 파싱 순서

1. `candidates[0].content.parts[0].text`에서 텍스트를 추출합니다.
2. `responseMimeType: "application/json"` 설정 시 텍스트가 유효한 JSON입니다.
3. `ObjectMapper`를 사용하여 `DiagnoseResponse`로 역직렬화합니다.
4. 파싱 실패 시 `AI_SERVICE_ERROR`를 반환합니다.

```java
private DiagnoseResponse parseResponse(String rawResponse) {
    try {
        ObjectMapper mapper = new ObjectMapper();
        JsonNode root = mapper.readTree(rawResponse);
        String jsonText = root
            .path("candidates").get(0)
            .path("content")
            .path("parts").get(0)
            .path("text")
            .asText();

        return mapper.readValue(jsonText, DiagnoseResponse.class);
    } catch (Exception e) {
        log.error("Gemini 응답 파싱 실패: {}", e.getMessage());
        throw new GeminiApiException("AI 응답 해석 실패", false);
    }
}
```

### 4.8 재시도 정책 상세

| 항목 | 값 |
|---|---|
| 최대 재시도 횟수 | 2회 (총 3회 시도) |
| 재시도 대상 | HTTP 5xx 응답, 연결 타임아웃, 읽기 타임아웃 |
| 재시도 비대상 | HTTP 4xx 응답 (인증 실패 등) |
| 백오프 전략 | 선형 백오프 (1초, 2초, 3초) |
| 최대 총 소요 시간 | 약 96초 (30초 × 3회 + 대기 6초) |

```
[1차 시도] ──실패──▶ [1초 대기] ──▶ [2차 시도] ──실패──▶ [2초 대기] ──▶ [3차 시도] ──실패──▶ AI_SERVICE_ERROR 반환
```

### 4.9 보안 고려사항

| 항목 | 대응 방안 |
|---|---|
| **프롬프트 인젝션** | 이력서 텍스트를 `---` 구분선으로 감싸고, System Prompt에서 JSON 형식만 응답하도록 강제 |
| **민감 정보 로깅** | 이력서 전문은 로그에 기록하지 않음. 요청 길이와 처리 시간만 기록 |
| **API 키 노출** | 환경변수 주입, `.gitignore`에 `.env` 포함, 응답에 API 키 미포함 |
| **입력 크기 제한** | 10,000자 제한으로 과도한 토큰 소비 및 비용 방지 |
| **출력 검증** | Gemini 응답의 JSON 스키마를 검증하여 예상치 못한 데이터 차단 |

---

## 부록: API 전체 요약

| 메서드 | 엔드포인트 | 설명 | 인증 | Rate Limit |
|---|---|---|---|---|
| `POST` | `/api/diagnose` | 이력서 AI 진단 | 없음 | 분당 10회 |
| `GET` | `/api/health` | 서버 상태 확인 | 없음 | 없음 |

## 부록: 프론트엔드 연동 예시 (TypeScript)

```typescript
interface DiagnoseRequest {
  resumeText: string;
}

interface DiagnoseResponse {
  score: number;
  readabilityFeedback: string[];
  contributionFeedback: string[];
  summary: string;
}

interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
  };
  timestamp: string;
}

async function diagnoseResume(resumeText: string): Promise<ApiResponse<DiagnoseResponse>> {
  const response = await fetch('/api/diagnose', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ resumeText }),
  });

  return response.json();
}
```
