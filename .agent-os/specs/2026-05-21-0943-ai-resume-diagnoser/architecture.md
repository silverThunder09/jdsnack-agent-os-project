# 시스템 아키텍처 문서

> 상태: 레거시 상세 문서  
> 현재 상위 아키텍처 문서:
> - [system-overview.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/architecture/system-overview.md)
> - [backend-architecture.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/architecture/backend-architecture.md)
> - [frontend-architecture.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/architecture/frontend-architecture.md)
> - [integration-architecture.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/architecture/integration-architecture.md)

> **프로젝트**: JDSnack — AI 이력서 진단 서비스  
> **버전**: 1.0  
> **최종 수정일**: 2026-05-21  
> **마감일**: 2026-05-26 (월)

---

## 1. 시스템 개요

### 1.1 아키텍처 요약

JDSnack은 **단일 JAR 배포 아키텍처**를 채택한다. 프론트엔드(React SPA)의 빌드 결과물을 Spring Boot의 정적 리소스 디렉토리에 포함시켜, 하나의 실행 가능한 JAR 파일로 전체 서비스를 운영한다. 이를 통해 별도의 웹 서버(Nginx 등)나 CDN 없이도 단일 프로세스로 프론트엔드와 백엔드를 동시에 서빙할 수 있다.

### 1.2 시스템 구성도 (텍스트 기반)

```
┌─────────────────────────────────────────────────────────────────────┐
│                        AWS EC2 (t3.micro)                          │
│                                                                     │
│  ┌──── (선택) Nginx :80 ──── 리버스 프록시 ────┐                    │
│  │                                              ▼                   │
│  │  ┌───────────────────────────────────────────────────────────┐   │
│  │  │              Spring Boot JAR (:8080)                      │   │
│  │  │                                                           │   │
│  │  │  ┌─────────────────────┐  ┌────────────────────────────┐ │   │
│  │  │  │  Static Resources   │  │       REST API Layer       │ │   │
│  │  │  │  (/static/**)       │  │   POST /api/diagnose       │ │   │
│  │  │  │                     │  │                            │ │   │
│  │  │  │  - index.html       │  │  Controller → Service      │ │   │
│  │  │  │  - assets/*.js      │  │       │                    │ │   │
│  │  │  │  - assets/*.css     │  │       ▼                    │ │   │
│  │  │  │                     │  │  GeminiService             │ │   │
│  │  │  └─────────────────────┘  │       │                    │ │   │
│  │  │                           │       │ HTTP (REST)        │ │   │
│  │  │                           └───────┼────────────────────┘ │   │
│  │  └───────────────────────────────────┼───────────────────────┘   │
│  └──────────────────────────────────────┼───────────────────────────┘
│                                         │
│                                         ▼
│                          ┌──────────────────────────┐
│                          │   Google Gemini API       │
│                          │   (generativelanguage     │
│                          │    .googleapis.com)       │
│                          └──────────────────────────┘
```

### 1.3 요청 흐름 (Request Flow)

사용자의 이력서 진단 요청은 다음 순서로 처리된다:

```
[1] 브라우저 (사용자)
     │
     │  GET /  (최초 접속)
     ▼
[2] Spring Boot — Static Resource Handler
     │  → index.html + JS/CSS 번들 반환
     ▼
[3] React SPA (브라우저에서 실행)
     │  사용자가 이력서 텍스트 입력 후 "진단하기" 클릭
     │
     │  POST /api/diagnose  { resumeText: "..." }
     ▼
[4] Spring Boot — ResumeController
     │  요청 유효성 검증 (빈 문자열, 길이 초과 등)
     ▼
[5] GeminiService
     │  프롬프트 구성 + Gemini API 호출
     │
     │  POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
     ▼
[6] Google Gemini API
     │  AI 분석 수행 → JSON 응답 반환
     ▼
[7] GeminiService
     │  응답 파싱 → DiagnoseResponse DTO 변환
     ▼
[8] ResumeController
     │  HTTP 200 + JSON 응답 반환
     ▼
[9] React SPA
     │  결과 렌더링 (점수 게이지 + 피드백 목록)
     │  LocalStorage에 결과 자동 저장
     ▼
[10] 브라우저 (사용자)
      진단 결과 확인
```

---

## 2. 프로젝트 디렉토리 구조

### 2.1 전체 트리 구조

```
JDSnack/
├── agent-os/                          # 스펙 및 표준 문서 관리 디렉토리
│   └── specs/
│       └── 2026-05-21-0943-ai-resume-diagnoser/
│           ├── requirements.md        # 기능/비기능 요구사항 명세
│           ├── architecture.md        # 시스템 아키텍처 문서 (본 문서)
│           ├── api-spec.md            # REST API 상세 명세
│           ├── ui-spec.md             # UI/UX 상세 명세
│           └── prompt-engineering.md  # Gemini 프롬프트 설계 문서
│
├── backend/                           # Spring Boot 백엔드 프로젝트 루트
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/jdsnack/
│   │   │   │   ├── JDSnackApplication.java       # Spring Boot 메인 클래스 (@SpringBootApplication)
│   │   │   │   ├── controller/
│   │   │   │   │   └── ResumeController.java     # REST 컨트롤러 — /api/diagnose 엔드포인트 처리
│   │   │   │   ├── service/
│   │   │   │   │   └── GeminiService.java        # Gemini API 호출 및 응답 파싱 비즈니스 로직
│   │   │   │   ├── dto/
│   │   │   │   │   ├── DiagnoseRequest.java      # 진단 요청 DTO (resumeText 필드)
│   │   │   │   │   └── DiagnoseResponse.java     # 진단 응답 DTO (score, feedbacks 등)
│   │   │   │   ├── exception/
│   │   │   │   │   ├── GlobalExceptionHandler.java  # @RestControllerAdvice 전역 예외 처리기
│   │   │   │   │   └── DiagnoseException.java       # 진단 과정 커스텀 예외 클래스
│   │   │   │   └── config/
│   │   │   │       └── WebConfig.java            # CORS, SPA 라우팅 포워딩 등 웹 설정
│   │   │   └── resources/
│   │   │       ├── application.yml               # 애플리케이션 설정 (포트, API 키, 모델 등)
│   │   │       └── static/                       # React 빌드 결과물 복사 위치 (빌드 시 자동 복사)
│   │   │           ├── index.html                # (빌드 산출물) SPA 진입점
│   │   │           └── assets/                   # (빌드 산출물) JS/CSS 번들 파일
│   │   └── test/
│   │       └── java/com/jdsnack/
│   │           ├── controller/
│   │           │   └── ResumeControllerTest.java  # 컨트롤러 단위/통합 테스트
│   │           └── service/
│   │               └── GeminiServiceTest.java     # 서비스 레이어 단위 테스트
│   ├── build.gradle                   # Gradle 빌드 스크립트 (의존성, 빌드 태스크, 프론트엔드 복사 태스크)
│   ├── settings.gradle                # Gradle 프로젝트 설정
│   ├── gradlew                        # Gradle Wrapper 실행 스크립트 (Unix)
│   ├── gradlew.bat                    # Gradle Wrapper 실행 스크립트 (Windows)
│   └── Dockerfile                     # Docker 이미지 빌드 설정 (선택사항)
│
├── frontend/                          # Vite + React + TypeScript 프론트엔드 프로젝트 루트
│   ├── src/
│   │   ├── App.tsx                    # 루트 컴포넌트 — 전체 레이아웃 및 상태 관리 허브
│   │   ├── main.tsx                   # React 앱 진입점 — DOM 마운트 및 StrictMode 래핑
│   │   ├── components/
│   │   │   ├── ResumeInput.tsx        # 이력서 텍스트 입력 폼 (textarea + 제출 버튼)
│   │   │   ├── DiagnoseReport.tsx     # 진단 결과 전체 보고서 래퍼 컴포넌트
│   │   │   ├── ScoreGauge.tsx         # 100점 만점 점수 시각화 게이지 컴포넌트
│   │   │   ├── FeedbackList.tsx       # 카테고리별 피드백 목록 렌더링 컴포넌트
│   │   │   └── LoadingSpinner.tsx     # API 호출 중 로딩 애니메이션 컴포넌트
│   │   ├── hooks/
│   │   │   └── useDiagnose.ts         # 진단 API 호출 커스텀 훅 (상태, 로딩, 에러 관리)
│   │   ├── services/
│   │   │   └── api.ts                 # fetch 래퍼 — 백엔드 API 통신 모듈
│   │   ├── types/
│   │   │   └── index.ts              # TypeScript 타입/인터페이스 정의 (DiagnoseRequest, DiagnoseResponse 등)
│   │   └── styles/
│   │       ├── index.css              # 글로벌 스타일 — 리셋, 레이아웃, 컴포넌트 스타일
│   │       └── variables.css          # CSS 커스텀 속성 — 색상, 폰트, 간격 디자인 토큰
│   ├── public/                        # 정적 에셋 (favicon 등)
│   ├── index.html                     # Vite HTML 템플릿 — React 앱 마운트 포인트
│   ├── vite.config.ts                 # Vite 빌드 설정 — 프록시, 빌드 출력 경로 등
│   ├── tsconfig.json                  # TypeScript 컴파일러 설정
│   ├── tsconfig.node.json             # Vite/Node 환경용 TypeScript 설정
│   └── package.json                   # npm 의존성 및 스크립트 정의
│
├── .gitignore                         # Git 추적 제외 파일 목록
└── README.md                          # 프로젝트 소개, 실행 방법, 배포 가이드
```

### 2.2 주요 디렉토리 역할 요약

| 디렉토리 | 역할 |
|----------|------|
| `agent-os/specs/` | 프로젝트 기획·설계 명세 문서 보관 |
| `backend/` | Spring Boot 3.x 기반 백엔드 API 서버 |
| `backend/src/main/resources/static/` | 프론트엔드 빌드 산출물이 복사되는 정적 리소스 위치 |
| `frontend/` | Vite + React + TypeScript 기반 SPA 프론트엔드 |
| `frontend/src/components/` | UI 컴포넌트 모음 (단일 책임 원칙 준수) |
| `frontend/src/hooks/` | 재사용 가능한 커스텀 React 훅 |
| `frontend/src/services/` | 외부 API 통신 로직 캡슐화 |
| `frontend/src/types/` | 프론트엔드 전역 타입 정의 |
| `frontend/src/styles/` | Vanilla CSS 스타일시트 (CSS 변수 활용) |

---

## 3. 백엔드 아키텍처

### 3.1 레이어드 아키텍처

백엔드는 3계층 아키텍처를 따르며, 의존성은 항상 **상위 → 하위** 방향으로 흐른다.

```
┌──────────────────────────────────────────────────┐
│              Controller Layer                     │
│  (ResumeController)                               │
│  - HTTP 요청/응답 처리                              │
│  - 요청 유효성 검증 (@Valid)                        │
│  - DTO ↔ JSON 직렬화/역직렬화                      │
│                         │                         │
│                         ▼ 의존                     │
├──────────────────────────────────────────────────┤
│              Service Layer                        │
│  (GeminiService)                                  │
│  - 비즈니스 로직 (프롬프트 구성, 응답 파싱)            │
│  - 외부 API 호출 (Gemini)                          │
│  - 예외 변환 및 전파                                │
│                         │                         │
│                         ▼ 호출                     │
├──────────────────────────────────────────────────┤
│            External API (Google Gemini)            │
│  - REST API 호출 (RestClient / WebClient)          │
│  - API 키 인증                                     │
│  - JSON 응답 수신                                  │
└──────────────────────────────────────────────────┘
```

### 3.2 각 레이어의 책임

#### Controller Layer — `ResumeController`

| 항목 | 내용 |
|------|------|
| **어노테이션** | `@RestController`, `@RequestMapping("/api")` |
| **엔드포인트** | `POST /api/diagnose` |
| **책임** | 요청 수신, 입력 검증, 서비스 호출, 응답 반환 |
| **의존성** | `GeminiService` (생성자 주입) |
| **반환 타입** | `ResponseEntity<DiagnoseResponse>` |

```java
@RestController
@RequestMapping("/api")
public class ResumeController {

    private final GeminiService geminiService;

    public ResumeController(GeminiService geminiService) {
        this.geminiService = geminiService;
    }

    @PostMapping("/diagnose")
    public ResponseEntity<DiagnoseResponse> diagnose(
            @Valid @RequestBody DiagnoseRequest request) {
        DiagnoseResponse response = geminiService.diagnose(request.getResumeText());
        return ResponseEntity.ok(response);
    }
}
```

#### 서비스 계층 — `GeminiService`

| 항목 | 내용 |
|------|------|
| **어노테이션** | `@Service` |
| **책임** | 프롬프트 조립, Gemini API 호출, JSON 응답 파싱, DTO 변환 |
| **의존성** | `RestClient` (Spring 6.1+), `ObjectMapper` |
| **설정값 주입** | `@Value("${gemini.api-key}")`, `@Value("${gemini.model}")` |

핵심 흐름:
1. 사용자 이력서 텍스트를 시스템 프롬프트와 결합하여 Gemini 요청 본문 구성
2. `RestClient`를 사용해 Gemini REST API 호출
3. 응답 JSON에서 `candidates[0].content.parts[0].text` 추출
4. 추출된 텍스트(JSON 형식)를 `DiagnoseResponse` DTO로 파싱
5. 파싱 실패 시 `DiagnoseException` 발생

### 3.3 DTO 설계

#### `DiagnoseRequest`

```java
public class DiagnoseRequest {

    @NotBlank(message = "이력서 텍스트는 필수입니다.")
    @Size(max = 5000, message = "이력서 텍스트는 5000자를 초과할 수 없습니다.")
    private String resumeText;

    // getter, setter, 기본 생성자
}
```

#### `DiagnoseResponse`

```java
public class DiagnoseResponse {

    private int score;                           // 총점 (0~100)
    private String summary;                      // 종합 요약 코멘트
    private List<FeedbackItem> readability;      // 가독성 피드백 목록
    private List<FeedbackItem> projectContribution; // 프로젝트 기여도 피드백 목록

    // 내부 클래스
    public static class FeedbackItem {
        private String category;     // 피드백 카테고리 (예: "문장 구조", "성과 수치화")
        private String comment;      // 상세 피드백 내용
        private String suggestion;   // 개선 제안
    }

    // getter, setter, 기본 생성자
}
```

### 3.4 예외 처리 전략

#### 예외 계층 구조

```
RuntimeException
  └── DiagnoseException              # 진단 과정 중 발생하는 모든 비즈니스 예외의 상위 클래스
        ├── (API 호출 실패)            → HTTP 502 Bad Gateway
        ├── (응답 파싱 실패)            → HTTP 502 Bad Gateway
        ├── (API 키 미설정)            → HTTP 500 Internal Server Error
        └── (요청 유효성 실패)          → HTTP 400 Bad Request (Spring Validation)
```

#### `GlobalExceptionHandler`

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    // 진단 비즈니스 예외 처리
    @ExceptionHandler(DiagnoseException.class)
    public ResponseEntity<ErrorResponse> handleDiagnoseException(DiagnoseException e) {
        ErrorResponse error = new ErrorResponse("DIAGNOSE_ERROR", e.getMessage());
        return ResponseEntity.status(HttpStatus.BAD_GATEWAY).body(error);
    }

    // 입력 유효성 검증 실패 처리
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidation(MethodArgumentNotValidException e) {
        String message = e.getBindingResult().getFieldErrors().stream()
                .map(FieldError::getDefaultMessage)
                .collect(Collectors.joining(", "));
        ErrorResponse error = new ErrorResponse("VALIDATION_ERROR", message);
        return ResponseEntity.badRequest().body(error);
    }

    // 예상치 못한 서버 오류 처리
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGeneral(Exception e) {
        ErrorResponse error = new ErrorResponse("INTERNAL_ERROR", "서버 내부 오류가 발생했습니다.");
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
    }
}
```

#### `ErrorResponse` DTO

```java
public class ErrorResponse {
    private String code;       // 에러 코드 (DIAGNOSE_ERROR, VALIDATION_ERROR, INTERNAL_ERROR)
    private String message;    // 사용자 표시용 에러 메시지
    private LocalDateTime timestamp;  // 에러 발생 시각

    public ErrorResponse(String code, String message) {
        this.code = code;
        this.message = message;
        this.timestamp = LocalDateTime.now();
    }
}
```

### 3.5 application.yml 설정

```yaml
server:
  port: 8080                            # 서버 포트 (AWS 배포 시 유지)

spring:
  application:
    name: jdsnack                       # 애플리케이션 이름

# Gemini API 설정
gemini:
  api-key: ${GEMINI_API_KEY}            # 환경변수에서 API 키 주입 (보안상 직접 입력 금지)
  model: gemini-2.0-flash               # 사용할 Gemini 모델 (빠른 응답을 위해 flash 모델 선택)
  api-url: https://generativelanguage.googleapis.com/v1beta  # Gemini API 베이스 URL

# 로깅 설정
logging:
  level:
    com.jdsnack: INFO                   # 애플리케이션 로그 레벨
    org.springframework.web: WARN       # Spring Web 로그 최소화
```

### 3.6 WebConfig — SPA 라우팅 지원

React SPA의 클라이언트 사이드 라우팅을 지원하기 위해, API 경로(`/api/**`)와 정적 리소스 경로를 제외한 모든 요청을 `index.html`로 포워딩한다.

```java
@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addViewControllers(ViewControllerRegistry registry) {
        // SPA 라우팅: API, 정적 리소스 외 모든 경로 → index.html 포워딩
        registry.addViewController("/{path:[^\\.]*}")
                .setViewName("forward:/index.html");
    }
}
```

---

## 4. 프론트엔드 아키텍처

### 4.1 컴포넌트 트리 구조

```
<App>                                    # 루트 컴포넌트 (전체 상태 관리)
  │
  ├── <header>                           # 서비스 로고 + 타이틀
  │
  ├── <main>
  │   ├── <ResumeInput>                  # 이력서 입력 영역
  │   │   ├── <textarea>                 # 이력서 텍스트 입력 필드
  │   │   ├── <글자수 카운터>              # 현재 글자수 / 최대 글자수 표시
  │   │   └── <button "진단하기">         # 진단 요청 트리거 버튼
  │   │
  │   ├── <LoadingSpinner>               # 조건부 렌더링: isLoading === true 일 때 표시
  │   │
  │   └── <DiagnoseReport>               # 조건부 렌더링: 진단 결과가 존재할 때 표시
  │       ├── <ScoreGauge>               # 원형 게이지로 점수(0~100) 시각화
  │       └── <FeedbackList>             # 가독성 + 프로젝트 기여도 피드백 렌더링
  │           ├── <가독성 섹션>
  │           │   └── <FeedbackItem> × N
  │           └── <프로젝트 기여도 섹션>
  │               └── <FeedbackItem> × N
  │
  └── <footer>                           # 저작권 표시
```

### 4.2 상태 관리 전략

외부 상태 관리 라이브러리(Redux, Zustand 등)를 사용하지 않고, **React의 내장 상태 관리**(useState + custom hooks)만으로 구현한다. 이 프로젝트의 상태 구조가 단순하고 컴포넌트 깊이가 얕아 내장 기능만으로 충분하다.

#### 상태 흐름도

```
App (상태 소유)
  │
  │  resumeText: string          ← ResumeInput에서 onChange로 갱신
  │  result: DiagnoseResponse    ← useDiagnose 훅에서 API 응답으로 갱신
  │  isLoading: boolean          ← useDiagnose 훅에서 요청 상태로 갱신
  │  error: string | null        ← useDiagnose 훅에서 에러 발생 시 갱신
  │
  ├── ResumeInput     ← props: resumeText, onChange, onSubmit, isLoading
  ├── LoadingSpinner  ← props: (없음, isLoading일 때 조건부 렌더링)
  └── DiagnoseReport  ← props: result
       ├── ScoreGauge    ← props: score
       └── FeedbackList  ← props: readability, projectContribution
```

#### useDiagnose 커스텀 훅

```typescript
// hooks/useDiagnose.ts
interface UseDiagnoseReturn {
  result: DiagnoseResponse | null;
  isLoading: boolean;
  error: string | null;
  diagnose: (resumeText: string) => Promise<void>;
  reset: () => void;
}

function useDiagnose(): UseDiagnoseReturn {
  const [result, setResult] = useState<DiagnoseResponse | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const diagnose = async (resumeText: string) => {
    setIsLoading(true);
    setError(null);
    try {
      const response = await apiDiagnose(resumeText);
      setResult(response);
      // LocalStorage에 자동 저장
      localStorage.setItem('jdsnack_last_result', JSON.stringify(response));
      localStorage.setItem('jdsnack_last_input', resumeText);
    } catch (err) {
      setError(err instanceof Error ? err.message : '진단 중 오류가 발생했습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  const reset = () => { setResult(null); setError(null); };

  return { result, isLoading, error, diagnose, reset };
}
```

### 4.3 API 호출 흐름

```
사용자 "진단하기" 클릭
        │
        ▼
 useDiagnose.diagnose(resumeText)
        │
        ├── [1] setIsLoading(true), setError(null)
        │        → LoadingSpinner 표시
        │        → 버튼 비활성화
        │
        ├── [2] api.ts → fetch("POST /api/diagnose", { resumeText })
        │        │
        │        ├── 성공 (HTTP 200)
        │        │   ├── response.json() → DiagnoseResponse
        │        │   ├── setResult(response)
        │        │   ├── localStorage.setItem(...)
        │        │   └── setIsLoading(false)
        │        │        → DiagnoseReport 렌더링
        │        │
        │        └── 실패 (HTTP 4xx/5xx 또는 네트워크 에러)
        │            ├── 에러 메시지 추출
        │            ├── setError(message)
        │            └── setIsLoading(false)
        │                 → 에러 메시지 표시
        │
        └── [3] finally: setIsLoading(false)
```

#### api.ts 구현 설계

```typescript
// services/api.ts
const API_BASE = '/api';

export async function diagnoseResume(resumeText: string): Promise<DiagnoseResponse> {
  const response = await fetch(`${API_BASE}/diagnose`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ resumeText }),
  });

  if (!response.ok) {
    const errorData = await response.json().catch(() => null);
    throw new Error(
      errorData?.message ?? `서버 오류가 발생했습니다. (${response.status})`
    );
  }

  return response.json();
}
```

### 4.4 LocalStorage 자동 저장 전략

사용자 경험 향상을 위해, 다음 데이터를 LocalStorage에 자동 저장하고 복원한다.

| 키 | 저장 시점 | 데이터 | 용도 |
|----|----------|--------|------|
| `jdsnack_last_input` | 진단 요청 성공 시 | 이력서 텍스트 (string) | 새로고침 후 입력 필드 복원 |
| `jdsnack_last_result` | 진단 응답 수신 시 | DiagnoseResponse (JSON) | 새로고침 후 결과 화면 복원 |

#### 복원 로직 (App 컴포넌트 초기화)

```typescript
// App.tsx 내부
useEffect(() => {
  const savedInput = localStorage.getItem('jdsnack_last_input');
  const savedResult = localStorage.getItem('jdsnack_last_result');

  if (savedInput) setResumeText(savedInput);
  if (savedResult) {
    try {
      setResult(JSON.parse(savedResult));
    } catch {
      localStorage.removeItem('jdsnack_last_result');
    }
  }
}, []);
```

#### 저장 용량 관리

- 이력서 텍스트 최대 5,000자 → 약 10KB
- DiagnoseResponse JSON → 약 5~15KB
- 전체 LocalStorage 사용량: 약 25KB 이하 (브라우저 제한 5MB 대비 충분)

---

## 5. 빌드 및 패키징 파이프라인

### 5.1 전체 빌드 프로세스

```
[1] 프론트엔드 빌드
    $ cd frontend
    $ npm install
    $ npm run build
    → frontend/dist/ 에 빌드 결과물 생성
       ├── index.html
       └── assets/
           ├── index-[hash].js
           └── index-[hash].css

         │
         ▼

[2] 빌드 결과물 복사
    frontend/dist/** → backend/src/main/resources/static/
    (Gradle 커스텀 태스크 또는 수동 복사)

         │
         ▼

[3] 백엔드 빌드
    $ cd backend
    $ ./gradlew clean bootJar
    → backend/build/libs/jdsnack-0.0.1-SNAPSHOT.jar 생성

         │
         ▼

[4] 최종 산출물
    단일 실행 가능 JAR: jdsnack-0.0.1-SNAPSHOT.jar
    (프론트엔드 정적 파일 포함)
```

### 5.2 Gradle 빌드 설정

#### build.gradle (핵심 부분)

```groovy
plugins {
    id 'java'
    id 'org.springframework.boot' version '3.3.0'
    id 'io.spring.dependency-management' version '1.1.5'
}

group = 'com.jdsnack'
version = '0.0.1-SNAPSHOT'

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(17)
    }
}

dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-validation'

    // JSON 처리 (Jackson은 spring-boot-starter-web에 포함)

    testImplementation 'org.springframework.boot:spring-boot-starter-test'
}

// ── 프론트엔드 빌드 결과물 복사 태스크 ──
task copyFrontend(type: Copy) {
    description = '프론트엔드 빌드 결과물을 Spring Boot 정적 리소스 디렉토리에 복사'
    from '../frontend/dist'
    into 'src/main/resources/static'
}

// bootJar 실행 전에 프론트엔드 복사 태스크 실행
bootJar {
    dependsOn copyFrontend
}

// clean 시 static 디렉토리도 정리
clean {
    delete 'src/main/resources/static'
}
```

### 5.3 Vite 빌드 설정

#### vite.config.ts

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      // 개발 중 API 요청을 백엔드로 프록시
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: 'dist',          // 빌드 출력 디렉토리
    emptyOutDir: true,       // 빌드 전 출력 디렉토리 비우기
    sourcemap: false,        // 프로덕션에서 소스맵 비활성화
  },
});
```

### 5.4 빌드 명령어 요약

| 단계 | 명령어 | 실행 위치 | 산출물 |
|------|--------|----------|--------|
| 프론트엔드 의존성 설치 | `npm install` | `frontend/` | `node_modules/` |
| 프론트엔드 빌드 | `npm run build` | `frontend/` | `frontend/dist/` |
| 백엔드 빌드 (프론트엔드 복사 포함) | `./gradlew clean bootJar` | `backend/` | `backend/build/libs/jdsnack-0.0.1-SNAPSHOT.jar` |
| 로컬 실행 (테스트) | `java -jar build/libs/jdsnack-0.0.1-SNAPSHOT.jar` | `backend/` | 서버 시작 (`:8080`) |

---

## 6. 배포 아키텍처 (AWS)

### 6.1 인프라 구성

| 항목 | 설정값 |
|------|--------|
| **클라우드** | AWS |
| **서비스** | EC2 (단일 인스턴스) |
| **인스턴스 타입** | t3.micro (vCPU 2, 메모리 1GB) |
| **AMI** | Amazon Linux 2023 |
| **리전** | ap-northeast-2 (서울) |
| **스토리지** | EBS gp3, 8GB |
| **탄력적 IP** | 할당 (고정 퍼블릭 IP) |

### 6.2 서버 초기 설정

#### Java 17 설치

```bash
# Amazon Linux 2023에서 Java 17 설치
sudo dnf install -y java-17-amazon-corretto-devel

# 설치 확인
java -version
# openjdk version "17.x.x" ...

# JAVA_HOME 환경변수 설정
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto' | sudo tee -a /etc/profile.d/java.sh
source /etc/profile.d/java.sh
```

#### 애플리케이션 디렉토리 구성

```bash
# 애플리케이션 전용 디렉토리 생성
sudo mkdir -p /opt/jdsnack
sudo chown ec2-user:ec2-user /opt/jdsnack

# JAR 파일 업로드 (로컬에서 SCP)
scp -i ~/.ssh/jdsnack-key.pem \
    backend/build/libs/jdsnack-0.0.1-SNAPSHOT.jar \
    ec2-user@<EC2_PUBLIC_IP>:/opt/jdsnack/jdsnack.jar
```

### 6.3 환경변수 설정

```bash
# 환경변수 파일 생성 (보안 — 파일 권한 제한)
sudo vi /opt/jdsnack/.env
```

```bash
# /opt/jdsnack/.env
GEMINI_API_KEY=실제_API_키_입력
```

```bash
# 파일 권한 제한 (소유자만 읽기 가능)
chmod 600 /opt/jdsnack/.env
```

### 6.4 JAR 직접 실행 (테스트용)

```bash
# 환경변수 로드 후 실행
export $(cat /opt/jdsnack/.env | xargs)
java -jar /opt/jdsnack/jdsnack.jar

# 또는 인라인으로 실행
GEMINI_API_KEY=실제_API_키 java -jar /opt/jdsnack/jdsnack.jar
```

### 6.5 systemd 서비스 등록 (프로덕션)

서버 재시작 시 자동 실행되도록 systemd 서비스로 등록한다.

#### 서비스 파일 생성

```bash
sudo vi /etc/systemd/system/jdsnack.service
```

```ini
[Unit]
Description=JDSnack AI Resume Diagnosis Service
After=network.target

[Service]
Type=simple
User=ec2-user
Group=ec2-user
WorkingDirectory=/opt/jdsnack

# 환경변수 파일 로드
EnvironmentFile=/opt/jdsnack/.env

# JVM 메모리 설정 (t3.micro 1GB RAM 고려)
ExecStart=/usr/bin/java \
    -Xms256m \
    -Xmx512m \
    -jar /opt/jdsnack/jdsnack.jar

# 비정상 종료 시 자동 재시작
Restart=on-failure
RestartSec=10

# 종료 시 최대 30초 대기
TimeoutStopSec=30

# 로그 출력 설정
StandardOutput=journal
StandardError=journal
SyslogIdentifier=jdsnack

[Install]
WantedBy=multi-user.target
```

#### 서비스 활성화 및 시작

```bash
# systemd 설정 리로드
sudo systemctl daemon-reload

# 서비스 활성화 (부팅 시 자동 시작)
sudo systemctl enable jdsnack

# 서비스 시작
sudo systemctl start jdsnack

# 상태 확인
sudo systemctl status jdsnack

# 로그 확인
sudo journalctl -u jdsnack -f
```

### 6.6 Nginx 리버스 프록시 (선택사항)

HTTP 80 포트로 들어오는 요청을 Spring Boot 8080 포트로 전달한다. 도메인 및 SSL 설정이 필요한 경우 권장한다.

#### 설치 및 설정

```bash
# Nginx 설치
sudo dnf install -y nginx

# 설정 파일 편집
sudo vi /etc/nginx/conf.d/jdsnack.conf
```

```nginx
server {
    listen 80;
    server_name _;              # 모든 도메인 허용 (또는 실제 도메인 지정)

    # 클라이언트 최대 요청 크기 (이력서 텍스트 전송 고려)
    client_max_body_size 1M;

    # 모든 요청을 Spring Boot로 프록시
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 타임아웃 설정 (Gemini API 응답 대기 고려)
        proxy_connect_timeout 10s;
        proxy_read_timeout 60s;
        proxy_send_timeout 10s;
    }
}
```

```bash
# 기본 설정의 server 블록 비활성화
sudo sed -i 's/listen       80;/# listen       80;/' /etc/nginx/nginx.conf

# 설정 테스트 및 시작
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl start nginx
```

### 6.7 보안 그룹 규칙 (Security Group)

EC2 인스턴스에 적용할 인바운드/아웃바운드 규칙:

#### 인바운드 규칙 (Inbound Rules)

| 타입 | 프로토콜 | 포트 범위 | 소스 | 용도 |
|------|---------|----------|------|------|
| SSH | TCP | 22 | 관리자 IP/32 | SSH 접속 (특정 IP만 허용) |
| HTTP | TCP | 80 | 0.0.0.0/0 | 웹 서비스 (Nginx 사용 시) |
| Custom TCP | TCP | 8080 | 0.0.0.0/0 | 웹 서비스 (Nginx 미사용 시, 직접 접근) |

> **주의**: 포트 22(SSH)는 반드시 관리자 IP만 허용하도록 설정한다. `0.0.0.0/0`으로 열지 않는다.

> **주의**: Nginx를 사용하는 경우 포트 8080은 외부에서 접근할 필요가 없으므로 인바운드 규칙에서 제거한다.

#### 아웃바운드 규칙 (Outbound Rules)

| 타입 | 프로토콜 | 포트 범위 | 대상 | 용도 |
|------|---------|----------|------|------|
| All Traffic | All | All | 0.0.0.0/0 | Gemini API 호출, 패키지 다운로드 등 |

### 6.8 배포 체크리스트

배포 전 확인해야 할 항목:

- [ ] `GEMINI_API_KEY` 환경변수가 올바르게 설정되었는가?
- [ ] `java -version`으로 Java 17 설치가 확인되었는가?
- [ ] 프론트엔드 빌드 결과물이 JAR에 포함되었는가? (`jar tf jdsnack.jar | grep static`)
- [ ] 보안 그룹에서 SSH 포트(22)가 관리자 IP로만 제한되었는가?
- [ ] systemd 서비스가 `enabled` 상태이며 정상 `active(running)`인가?
- [ ] `curl http://localhost:8080` 으로 index.html이 반환되는가?
- [ ] `curl -X POST http://localhost:8080/api/diagnose -H "Content-Type: application/json" -d '{"resumeText":"테스트"}'` 로 정상 응답을 받는가?
- [ ] 탄력적 IP가 인스턴스에 연결되었는가?
- [ ] (선택) Nginx가 정상 동작하며 80 → 8080 프록시가 되는가?

---

## 부록: 기술 스택 요약

| 영역 | 기술 | 버전 |
|------|------|------|
| 언어 (백엔드) | Java | 17 (LTS) |
| 프레임워크 (백엔드) | Spring Boot | 3.3.x |
| 빌드 도구 | Gradle | 8.x |
| 언어 (프론트엔드) | TypeScript | 5.x |
| UI 프레임워크 | React | 18.x |
| 빌드 도구 (프론트엔드) | Vite | 5.x |
| 스타일링 | Vanilla CSS | - |
| AI | Google Gemini API | v1beta |
| 배포 | AWS EC2 | t3.micro |
| OS | Amazon Linux | 2023 |
| 리버스 프록시 | Nginx | 1.x (선택) |
