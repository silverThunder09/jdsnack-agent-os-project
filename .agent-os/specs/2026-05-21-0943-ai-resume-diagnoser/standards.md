# 개발 표준 및 코딩 컨벤션

> 상태: 레거시 상세 문서  
> 현재 상위 표준 문서:
> - [standards/codex-harness.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/standards/codex-harness.md)
> - [standards/coding-standards.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/standards/coding-standards.md)
> - [standards/testing-standards.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/standards/testing-standards.md)
> - [standards/definition-of-done.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/standards/definition-of-done.md)

> **프로젝트명:** JDSnack — AI 이력서 진단 웹 서비스  
> **최종 수정:** 2026-05-21  
> **적용 범위:** 프로젝트 전체 (백엔드, 프론트엔드, 인프라)

이 문서는 JDSnack 프로젝트의 모든 코드에 적용되는 개발 표준과 코딩 컨벤션을 정의한다. 모든 팀원(또는 AI 에이전트)은 이 표준을 준수하여 일관된 코드 품질을 유지해야 한다.

---

## 1. 백엔드 코딩 컨벤션 (Spring Boot / Java)

### 1.1 패키지 구조

```
com.jdsnack
├── controller/       # REST API 컨트롤러
│   └── ResumeController.java
├── service/          # 비즈니스 로직 서비스
│   ├── GeminiService.java
│   └── DiagnoseService.java
├── dto/              # 요청/응답 데이터 전송 객체
│   ├── DiagnoseRequest.java
│   ├── DiagnoseResponse.java
│   └── ApiResponse.java
├── exception/        # 예외 클래스 및 글로벌 핸들러
│   ├── GeminiApiException.java
│   └── GlobalExceptionHandler.java
└── config/           # 설정 클래스
    ├── GeminiConfig.java
    └── WebConfig.java
```

### 1.2 네이밍 규칙

| 대상 | 규칙 | 예시 |
|------|------|------|
| 클래스명 | PascalCase | `ResumeController`, `GeminiService`, `DiagnoseRequest` |
| 메서드명 | camelCase (동사로 시작) | `diagnoseResume()`, `callGeminiApi()`, `parseResponse()` |
| 변수명 | camelCase | `resumeText`, `apiKey`, `maxTokens` |
| 상수 | UPPER_SNAKE_CASE | `MAX_OUTPUT_TOKENS`, `API_TIMEOUT_SECONDS` |
| 패키지명 | 모두 소문자, 단수형 | `controller`, `service`, `dto` |
| 설정 키 | kebab-case | `gemini.api-key`, `gemini.max-output-tokens` |

### 1.3 DTO: record 클래스 사용

Java 17+의 `record` 클래스를 DTO로 사용하여 불변성과 간결성을 보장한다.

```java
// ✅ 권장: record 사용
public record DiagnoseRequest(
    @NotBlank(message = "이력서 텍스트는 필수입니다")
    String resumeText
) {}

public record DiagnoseResponse(
    int score,
    ReadabilityFeedback readability,
    ContributionFeedback contribution,
    String summary
) {}

// ❌ 지양: 기존 class + getter/setter
public class DiagnoseRequest {
    private String resumeText;
    public String getResumeText() { return resumeText; }
    public void setResumeText(String text) { this.resumeText = text; }
}
```

### 1.4 공통 API 응답 래퍼

모든 API 응답은 `ApiResponse<T>` 래퍼로 감싸서 일관된 형식을 유지한다.

```java
public record ApiResponse<T>(
    boolean success,
    T data,
    String error,
    LocalDateTime timestamp
) {
    public static <T> ApiResponse<T> success(T data) {
        return new ApiResponse<>(true, data, null, LocalDateTime.now());
    }

    public static <T> ApiResponse<T> error(String message) {
        return new ApiResponse<>(false, null, message, LocalDateTime.now());
    }
}
```

**응답 예시 (성공):**
```json
{
  "success": true,
  "data": {
    "score": 72,
    "readability": { ... },
    "contribution": { ... },
    "summary": "전반적으로 양호한 이력서입니다..."
  },
  "error": null,
  "timestamp": "2026-05-22T14:30:00"
}
```

**응답 예시 (실패):**
```json
{
  "success": false,
  "data": null,
  "error": "AI 서비스에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.",
  "timestamp": "2026-05-22T14:30:00"
}
```

### 1.5 예외 처리

`@RestControllerAdvice`를 사용한 글로벌 예외 핸들러로 모든 예외를 일관되게 처리한다.

```java
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(GeminiApiException.class)
    public ResponseEntity<ApiResponse<Void>> handleGeminiApiException(GeminiApiException e) {
        log.error("Gemini API 호출 실패: {}", e.getMessage(), e);
        return ResponseEntity
            .status(HttpStatus.SERVICE_UNAVAILABLE)
            .body(ApiResponse.error("AI 서비스에 일시적인 문제가 발생했습니다."));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<Void>> handleValidation(MethodArgumentNotValidException e) {
        String message = e.getBindingResult().getFieldErrors().stream()
            .map(FieldError::getDefaultMessage)
            .findFirst()
            .orElse("입력값을 확인해 주세요.");
        return ResponseEntity
            .badRequest()
            .body(ApiResponse.error(message));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleGeneral(Exception e) {
        log.error("예기치 않은 에러 발생: {}", e.getMessage(), e);
        return ResponseEntity
            .status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(ApiResponse.error("서버 내부 오류가 발생했습니다."));
    }
}
```

### 1.6 로깅 표준

- **프레임워크:** SLF4J + Logback (Spring Boot 기본 제공)
- **어노테이션:** Lombok `@Slf4j` 사용
- **로그 레벨 기준:**

| 레벨 | 사용 시점 | 예시 |
|------|-----------|------|
| `ERROR` | 시스템 장애, 외부 API 실패 | `log.error("Gemini API 호출 실패: {}", e.getMessage(), e)` |
| `WARN` | 예상 가능한 문제 상황 | `log.warn("Gemini 응답 파싱 실패, 재시도: {}", attempt)` |
| `INFO` | 주요 비즈니스 흐름 | `log.info("이력서 진단 요청 수신, 텍스트 길이: {}", text.length())` |
| `DEBUG` | 개발 시 상세 디버깅 | `log.debug("Gemini 프롬프트: {}", prompt)` |

- **필수 로그 지점:**
  - API 요청 수신 시 (INFO): 요청 메서드, 경로, 입력 데이터 크기
  - API 응답 반환 시 (INFO): 응답 상태, 처리 시간
  - 외부 API 호출 전/후 (DEBUG/INFO): 호출 대상, 응답 시간
  - 예외 발생 시 (ERROR): 예외 메시지, 스택 트레이스

### 1.7 컨트롤러 작성 표준

```java
@RestController
@RequestMapping("/api")
@Slf4j
@RequiredArgsConstructor
public class ResumeController {

    private final DiagnoseService diagnoseService;

    @PostMapping("/diagnose")
    public ResponseEntity<ApiResponse<DiagnoseResponse>> diagnose(
            @Valid @RequestBody DiagnoseRequest request) {
        log.info("이력서 진단 요청 수신, 텍스트 길이: {}", request.resumeText().length());
        DiagnoseResponse response = diagnoseService.diagnose(request);
        return ResponseEntity.ok(ApiResponse.success(response));
    }
}
```

---

## 2. 프론트엔드 코딩 컨벤션 (React / TypeScript)

### 2.1 디렉토리 구조

```
frontend/src/
├── components/           # 리액트 컴포넌트
│   ├── Header.tsx
│   ├── Header.css
│   ├── ResumeInput.tsx
│   ├── ResumeInput.css
│   ├── DiagnoseReport.tsx
│   ├── DiagnoseReport.css
│   ├── ScoreDisplay.tsx
│   ├── ScoreDisplay.css
│   ├── LoadingSpinner.tsx
│   └── LoadingSpinner.css
├── hooks/                # 커스텀 훅
│   └── useDiagnose.ts
├── api/                  # API 호출 함수
│   └── diagnoseApi.ts
├── types/                # 타입 정의
│   └── index.ts
├── styles/               # 글로벌 스타일
│   └── global.css
├── App.tsx               # 루트 컴포넌트
├── App.css               # 앱 레벨 스타일
└── main.tsx              # 엔트리 포인트
```

### 2.2 컴포넌트 작성 규칙

- **함수형 컴포넌트만 사용** (클래스 컴포넌트 사용 금지)
- **`React.FC` 타입 사용 금지** — props 인터페이스를 직접 정의하여 명시성을 높인다
- **하나의 파일에 하나의 컴포넌트** (default export 사용)

```tsx
// ✅ 권장
interface ResumeInputProps {
  onSubmit: (text: string) => void;
  isLoading: boolean;
}

function ResumeInput({ onSubmit, isLoading }: ResumeInputProps) {
  const [text, setText] = useState('');

  const handleSubmit = () => {
    if (text.trim()) {
      onSubmit(text);
    }
  };

  return (
    <div className="resume-input">
      <textarea
        className="resume-input__textarea"
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder="이력서 내용을 붙여넣으세요..."
      />
      <button
        className="resume-input__button"
        onClick={handleSubmit}
        disabled={isLoading || !text.trim()}
      >
        {isLoading ? '분석 중...' : '진단하기'}
      </button>
    </div>
  );
}

export default ResumeInput;
```

```tsx
// ❌ 지양: React.FC 사용
const ResumeInput: React.FC<ResumeInputProps> = ({ onSubmit }) => { ... }
```

### 2.3 파일 네이밍 규칙

| 대상 | 규칙 | 예시 |
|------|------|------|
| 컴포넌트 파일 | PascalCase `.tsx` | `ResumeInput.tsx`, `DiagnoseReport.tsx` |
| 컴포넌트 CSS | PascalCase `.css` (컴포넌트와 동일명) | `ResumeInput.css`, `DiagnoseReport.css` |
| 커스텀 훅 | camelCase `use` 접두어 `.ts` | `useDiagnose.ts`, `useLocalStorage.ts` |
| API 함수 | camelCase `.ts` | `diagnoseApi.ts` |
| 타입 정의 | camelCase `.ts` | `types/index.ts` |
| 유틸리티 | camelCase `.ts` | `utils/formatScore.ts` |

### 2.4 상태 관리

- **기본:** `useState` + `useEffect` 조합
- **복잡한 로직:** 커스텀 훅으로 추출
- **전역 상태 관리 라이브러리 사용 금지** (프로젝트 규모에 비해 과도)

```ts
// hooks/useDiagnose.ts
import { useState } from 'react';
import { diagnoseResume } from '../api/diagnoseApi';
import type { DiagnoseResponse } from '../types';

interface UseDiagnoseReturn {
  result: DiagnoseResponse | null;
  isLoading: boolean;
  error: string | null;
  diagnose: (text: string) => Promise<void>;
  reset: () => void;
}

function useDiagnose(): UseDiagnoseReturn {
  const [result, setResult] = useState<DiagnoseResponse | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const diagnose = async (text: string) => {
    setIsLoading(true);
    setError(null);
    try {
      const response = await diagnoseResume(text);
      setResult(response);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'AI 분석 중 오류가 발생했습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  const reset = () => {
    setResult(null);
    setError(null);
  };

  return { result, isLoading, error, diagnose, reset };
}

export default useDiagnose;
```

### 2.5 API 호출 표준

- **`fetch` API만 사용** (axios 등 외부 라이브러리 사용 금지 — 의존성 최소화)
- API 기본 URL은 환경 변수 또는 상대 경로 사용

```ts
// api/diagnoseApi.ts
import type { ApiResponse, DiagnoseResponse } from '../types';

const API_BASE_URL = '/api';

export async function diagnoseResume(resumeText: string): Promise<DiagnoseResponse> {
  const response = await fetch(`${API_BASE_URL}/diagnose`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ resumeText }),
  });

  if (!response.ok) {
    const errorBody = await response.json().catch(() => null);
    throw new Error(
      errorBody?.error || `서버 오류가 발생했습니다. (${response.status})`
    );
  }

  const apiResponse: ApiResponse<DiagnoseResponse> = await response.json();

  if (!apiResponse.success) {
    throw new Error(apiResponse.error || 'AI 분석에 실패했습니다.');
  }

  return apiResponse.data;
}
```

### 2.6 타입 정의

모든 타입은 `types/index.ts`에 중앙 집중 관리한다.

```ts
// types/index.ts

/** 공통 API 응답 래퍼 */
export interface ApiResponse<T> {
  success: boolean;
  data: T;
  error: string | null;
  timestamp: string;
}

/** 이력서 진단 응답 */
export interface DiagnoseResponse {
  score: number;
  readability: ReadabilityFeedback;
  contribution: ContributionFeedback;
  summary: string;
}

/** 가독성 피드백 */
export interface ReadabilityFeedback {
  grade: string;
  details: string[];
  suggestions: string[];
}

/** 프로젝트 기여도 피드백 */
export interface ContributionFeedback {
  grade: string;
  details: string[];
  suggestions: string[];
}
```

---

## 3. CSS 스타일링 표준

### 3.1 CSS 변수 (Custom Properties)

모든 색상, 간격, 폰트 크기 등은 `:root`에 CSS 변수로 정의하여 일관성과 유지보수성을 확보한다.

```css
:root {
  /* ── 색상 ── */
  --color-primary: #007AFF;
  --color-primary-hover: #005EC4;
  --color-background: #FFFFFF;
  --color-surface: #F5F5F7;
  --color-border: #D2D2D7;
  --color-text-primary: #1D1D1F;
  --color-text-secondary: #6E6E73;
  --color-text-tertiary: #86868B;
  --color-success: #34C759;
  --color-warning: #FF9500;
  --color-error: #FF3B30;

  /* ── 폰트 크기 ── */
  --font-size-xs: 0.75rem;    /* 12px */
  --font-size-sm: 0.875rem;   /* 14px */
  --font-size-base: 1rem;     /* 16px */
  --font-size-lg: 1.125rem;   /* 18px */
  --font-size-xl: 1.5rem;     /* 24px */
  --font-size-2xl: 2rem;      /* 32px */
  --font-size-3xl: 3rem;      /* 48px */

  /* ── 폰트 패밀리 ── */
  --font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI',
    'Noto Sans KR', sans-serif;

  /* ── 간격 (8px 그리드) ── */
  --spacing-xs: 4px;
  --spacing-sm: 8px;
  --spacing-md: 16px;
  --spacing-lg: 24px;
  --spacing-xl: 32px;
  --spacing-2xl: 48px;
  --spacing-3xl: 64px;

  /* ── 둥글기 ── */
  --radius-sm: 8px;
  --radius-md: 12px;
  --radius-lg: 16px;
  --radius-full: 9999px;

  /* ── 그림자 ── */
  --shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.08);
  --shadow-md: 0 4px 12px rgba(0, 0, 0, 0.1);
  --shadow-lg: 0 8px 24px rgba(0, 0, 0, 0.12);

  /* ── 트랜지션 ── */
  --transition-default: all 0.2s cubic-bezier(0.25, 0.1, 0.25, 1);

  /* ── 레이아웃 ── */
  --max-width: 720px;
  --header-height: 64px;
}
```

### 3.2 8px 그리드 시스템

모든 간격(margin, padding)과 크기는 **8px의 배수**를 기본으로 사용한다. 세밀한 조정이 필요한 경우 4px 단위를 허용한다.

```css
/* ✅ 권장: 8px 배수 사용 */
.card {
  padding: var(--spacing-lg);       /* 24px */
  margin-bottom: var(--spacing-md); /* 16px */
  gap: var(--spacing-sm);           /* 8px */
}

/* ❌ 지양: 임의의 값 사용 */
.card {
  padding: 15px;
  margin-bottom: 13px;
  gap: 7px;
}
```

### 3.3 BEM 네이밍 컨벤션

CSS 클래스명은 **BEM (Block__Element--Modifier)** 규칙을 따른다.

```css
/* Block: 독립적인 컴포넌트 */
.resume-input { }

/* Element: Block의 하위 요소 */
.resume-input__textarea { }
.resume-input__button { }
.resume-input__counter { }

/* Modifier: 상태 또는 변형 */
.resume-input__button--disabled { }
.resume-input__button--loading { }
.diagnose-report__score--high { }   /* 80점 이상 */
.diagnose-report__score--medium { } /* 50~79점 */
.diagnose-report__score--low { }    /* 50점 미만 */
```

### 3.4 미디어 쿼리 브레이크포인트

| 이름 | 범위 | 용도 |
|------|------|------|
| Mobile | `< 768px` | 모바일 화면 |
| Tablet | `768px ~ 1199px` | 태블릿 (기본 레이아웃) |
| Desktop | `≥ 1200px` | 데스크톱 와이드 |

```css
/* 모바일 퍼스트 접근 */

/* 기본 스타일 = 모바일 */
.container {
  padding: var(--spacing-md);
  max-width: 100%;
}

/* 태블릿 이상 */
@media (min-width: 768px) {
  .container {
    padding: var(--spacing-xl);
    max-width: var(--max-width);
    margin: 0 auto;
  }
}

/* 데스크톱 */
@media (min-width: 1200px) {
  .container {
    max-width: 960px;
  }
}
```

### 3.5 트랜지션 표준

모든 인터랙션 트랜지션은 통일된 이징 함수를 사용한다.

```css
/* ✅ 권장: CSS 변수 사용 */
.button {
  transition: var(--transition-default);
}

/* 또는 직접 명시할 때도 동일한 이징 함수 사용 */
.card {
  transition: transform 0.2s cubic-bezier(0.25, 0.1, 0.25, 1),
              box-shadow 0.2s cubic-bezier(0.25, 0.1, 0.25, 1);
}

/* ❌ 지양: 다른 이징 함수 사용 */
.card {
  transition: all 0.3s ease-in-out;
}
```

---

## 4. Git 커밋 컨벤션

### 4.1 커밋 메시지 형식

```
<type>: <subject>
```

- **type:** 변경 유형을 나타내는 접두어
- **subject:** 변경 내용을 간결하게 설명 (한글 사용)

### 4.2 커밋 타입

| 타입 | 설명 | 예시 |
|------|------|------|
| `feat` | 새로운 기능 추가 | `feat: 이력서 진단 API 엔드포인트 구현` |
| `fix` | 버그 수정 | `fix: Gemini 응답 JSON 파싱 오류 수정` |
| `docs` | 문서 변경 | `docs: API 명세서 업데이트` |
| `style` | 코드 포맷팅 (기능 변경 없음) | `style: import 정렬 및 들여쓰기 수정` |
| `refactor` | 리팩토링 (기능 변경 없음) | `refactor: GeminiService 메서드 분리` |
| `test` | 테스트 코드 추가/수정 | `test: 진단 API 통합 테스트 추가` |
| `chore` | 빌드/설정 변경 | `chore: Gradle 프론트엔드 빌드 태스크 추가` |
| `deploy` | 배포 관련 변경 | `deploy: AWS EB 환경 설정 추가` |

### 4.3 커밋 규칙

- **한 커밋에 한 가지 변경**만 포함한다
- **커밋 메시지는 한글**로 작성한다 (type 접두어는 영문)
- 제목은 **50자 이내**로 작성한다
- 필요 시 본문에 상세 설명을 추가한다 (빈 줄로 구분)

```
feat: 이력서 진단 API 엔드포인트 구현

- POST /api/diagnose 엔드포인트 추가
- DiagnoseRequest, DiagnoseResponse DTO 정의
- 입력값 검증 로직 추가 (@Valid, @NotBlank)
```

### 4.4 브랜치 전략

MVP 개발 기간 중에는 **단일 `main` 브랜치**에서 직접 커밋한다. 프로젝트 규모와 일정을 고려하여 별도 브랜치 전략은 사용하지 않는다.

---

## 5. Gemini API 프롬프트 표준

### 5.1 API 호출 설정

| 설정 항목 | 값 | 설명 |
|-----------|-----|------|
| 모델 | `gemini-2.0-flash` | 빠른 응답 속도와 적절한 품질의 균형 |
| Temperature | `0.3` | 낮은 값으로 일관된 분석 결과 보장 |
| maxOutputTokens | `2048` | 상세한 피드백을 위한 충분한 토큰 수 |
| 타임아웃 | `30초` | 네트워크 지연 대비 |
| 응답 형식 | **JSON 강제** | 프롬프트에서 JSON 형식을 명시적으로 요구 |

### 5.2 프롬프트 템플릿

```text
당신은 전문 이력서 컨설턴트입니다. 아래 이력서를 분석하여 정확히 다음 JSON 형식으로만 응답해 주세요.
다른 텍스트 없이 오직 JSON만 반환해 주세요.

JSON 형식:
{
  "score": <0~100 사이의 정수>,
  "readability": {
    "grade": "<상/중/하 중 하나>",
    "details": ["<가독성 관련 분석 내용 1>", "<가독성 관련 분석 내용 2>", ...],
    "suggestions": ["<가독성 개선 제안 1>", "<가독성 개선 제안 2>", ...]
  },
  "contribution": {
    "grade": "<상/중/하 중 하나>",
    "details": ["<프로젝트 기여도 분석 내용 1>", "<프로젝트 기여도 분석 내용 2>", ...],
    "suggestions": ["<기여도 표현 개선 제안 1>", "<기여도 표현 개선 제안 2>", ...]
  },
  "summary": "<종합 평가 요약 (2~3문장)>"
}

평가 기준:
1. 가독성 (40점): 문장 구조, 글머리 기호 활용, 섹션 구분, 오탈자, 전문 용어 사용 적절성
2. 프로젝트 기여도 (40점): 구체적 성과 수치 포함 여부, 본인 역할 명시, 기술 스택 활용도, STAR 기법 적용
3. 전체 구성 (20점): 이력서 전체 흐름, 핵심 역량 전달력, 채용 담당자 관점 매력도

분석할 이력서:
---
{resumeText}
---
```

### 5.3 JSON 응답 스키마

Gemini API가 반환해야 하는 JSON 스키마:

```json
{
  "score": 72,
  "readability": {
    "grade": "중",
    "details": [
      "문장이 전반적으로 길어 가독성이 떨어집니다.",
      "글머리 기호가 일관되게 사용되고 있습니다.",
      "섹션 구분이 명확합니다."
    ],
    "suggestions": [
      "한 문장은 50자 이내로 줄여 보세요.",
      "핵심 키워드를 문장 앞에 배치하면 눈에 띄기 쉽습니다.",
      "불필요한 조사를 줄이면 간결해집니다."
    ]
  },
  "contribution": {
    "grade": "중",
    "details": [
      "프로젝트 성과가 정성적으로만 기술되어 있습니다.",
      "본인의 역할이 명확히 구분되어 있습니다.",
      "기술 스택 나열은 잘 되어 있으나 활용 맥락이 부족합니다."
    ],
    "suggestions": [
      "성과를 수치로 표현하세요 (예: 'API 응답 시간 40% 개선').",
      "STAR 기법을 적용하여 상황-과제-행동-결과를 구조화하세요.",
      "기술을 어떤 문제 해결에 활용했는지 맥락을 추가하세요."
    ]
  },
  "summary": "전반적으로 기본 구성이 갖춰진 이력서입니다. 가독성은 양호하나 프로젝트 기여도 표현에서 구체적인 수치와 성과 중심 서술이 부족합니다. STAR 기법을 적용하고 정량적 성과를 추가하면 훨씬 경쟁력 있는 이력서가 될 것입니다."
}
```

### 5.4 JSON 파싱 안전 처리

Gemini가 JSON 외 텍스트(마크다운 코드 블록 등)를 포함하여 응답할 수 있으므로, 다음과 같이 안전하게 파싱한다:

```java
/**
 * Gemini 응답에서 JSON 부분만 추출하여 파싱한다.
 * 마크다운 코드 블록(```json ... ```)이 포함된 경우에도 처리 가능.
 */
private DiagnoseResponse parseGeminiResponse(String rawResponse) {
    String jsonStr = rawResponse.trim();

    // 마크다운 코드 블록 제거
    if (jsonStr.startsWith("```")) {
        jsonStr = jsonStr.replaceAll("^```[a-zA-Z]*\\n?", "")
                         .replaceAll("\\n?```$", "");
    }

    try {
        return objectMapper.readValue(jsonStr, DiagnoseResponse.class);
    } catch (JsonProcessingException e) {
        log.error("Gemini 응답 JSON 파싱 실패: {}", rawResponse, e);
        throw new GeminiApiException("AI 응답을 처리할 수 없습니다.");
    }
}
```

### 5.5 프롬프트 보안 가이드

- **API Key는 절대 클라이언트(프론트엔드)에 노출하지 않는다**
- API Key는 서버 측 환경 변수(`GEMINI_API_KEY`)로만 관리한다
- `application.yml`에 API Key를 직접 작성하지 않고, `${GEMINI_API_KEY}`로 참조한다
- `.gitignore`에 환경 변수 파일(`.env`, `application-local.yml`)을 반드시 추가한다

```yaml
# application.yml
gemini:
  api-key: ${GEMINI_API_KEY}
  model: gemini-2.0-flash
  temperature: 0.3
  max-output-tokens: 2048
  timeout-seconds: 30
```

---

## 6. 프로젝트 빌드 및 실행 표준

### 6.1 로컬 개발 환경

```bash
# 백엔드 실행 (8080 포트)
GEMINI_API_KEY=your-key-here ./gradlew bootRun

# 프론트엔드 개발 서버 실행 (5173 포트 → 8080 프록시)
cd frontend && npm run dev
```

### 6.2 프로덕션 빌드

```bash
# 프론트엔드 빌드 + Spring Boot JAR 패키징 (한 번에)
./gradlew bootJar

# 실행
GEMINI_API_KEY=your-key-here java -jar build/libs/jdsnack.jar
```

### 6.3 Vite 프록시 설정

개발 환경에서 프론트엔드 → 백엔드 API 호출을 위한 프록시 설정:

```ts
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: '../src/main/resources/static',
    emptyOutDir: true,
  },
});
```
