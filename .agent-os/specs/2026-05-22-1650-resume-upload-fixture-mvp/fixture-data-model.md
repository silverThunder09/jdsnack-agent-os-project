# Fixture 데이터 모델

> 프로젝트: JDSnack — 1.5차 MVP 이력서 업로드 + fixture 분석
> 목적: 실제 AI 호출 없이도 업로드/분석 결과 화면을 검증할 수 있도록 입력 매핑과 분석 결과 구조를 고정한다.

## 1. 설계 원칙

- fixture는 분석을 생성하지 않고, 준비된 결과를 반환만 한다.
- 입력 원문과 분석 결과는 분리 저장한다.
- 1.5차 MVP에서는 영구 운영 DB보다 정적 JSON 또는 H2 같은 경량 저장소를 우선한다.
- 2차 MVP에서 실제 AI 분석기로 교체할 수 있도록 `DiagnosisProvider` 경계를 유지한다.

## 2. 데이터 계층

fixture 데이터는 두 계층으로 나눈다.

1. 입력 매핑 계층
- 어떤 입력이 어떤 fixture 결과를 사용할지 결정한다.

2. 분석 결과 계층
- 화면에 렌더링할 분석 결과 본문을 저장한다.

## 3. 입력 매핑 구조

### 3.1 `ResumeFixtureMapping`

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `mappingId` | string | 예 | 매핑 식별자 |
| `inputType` | string | 예 | `TEXT`, `PDF`, `DOCX` |
| `matchType` | string | 예 | `TEXT_HASH`, `FILE_NAME`, `FIXTURE_KEY` |
| `matchValue` | string | 예 | 텍스트 해시 또는 파일명 등 비교값 |
| `fixtureKey` | string | 예 | 연결할 분석 결과 키 |
| `title` | string | 아니오 | 샘플 이름 |
| `createdAt` | string | 예 | ISO-8601 시각 |
| `active` | boolean | 예 | 사용 여부 |

### 3.2 매칭 규칙

- 텍스트 입력은 기본적으로 `TEXT_HASH`를 사용한다.
- 파일 업로드는 초기에는 `FILE_NAME` 또는 추출 텍스트의 `TEXT_HASH`를 사용한다.
- 운영 안정성을 위해 1.5차 MVP 초반에는 파일명 기반 샘플 매핑도 허용한다.
- 같은 입력이 여러 결과에 매핑되면 안 된다.

## 4. 분석 결과 구조

### 4.1 `FixtureAnalysis`

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `fixtureKey` | string | 예 | 분석 결과 식별자 |
| `version` | string | 예 | 결과 스키마 버전, 예: `v1` |
| `score` | number | 예 | 0~100 점수 |
| `summary` | string | 예 | 한 줄 또는 짧은 문단 요약 |
| `strengths` | string[] | 예 | 강점 목록 |
| `improvements` | string[] | 예 | 개선 포인트 목록 |
| `keywords` | string[] | 아니오 | 추출 또는 표시용 키워드 |
| `sourceType` | string | 예 | `FIXTURE` 고정 |
| `locale` | string | 예 | 기본 `ko-KR` |
| `createdAt` | string | 예 | ISO-8601 시각 |
| `updatedAt` | string | 아니오 | 마지막 수정 시각 |

### 4.2 응답 최소 보장 필드

1. `score`
2. `summary`
3. `strengths`
4. `improvements`

`keywords`, `locale`, `version`은 내부 저장 또는 확장용으로 두되, API 응답에는 필요 시 포함한다.

## 5. API 응답 DTO 구조

### 5.1 `DiagnosisResultResponse`

```json
{
  "score": 78,
  "summary": "백엔드 중심 경험은 분명하지만 성과 수치가 더 필요합니다.",
  "strengths": [
    "Spring Boot API 구현 경험이 보입니다."
  ],
  "improvements": [
    "프로젝트 결과를 수치로 보강해 주세요."
  ]
}
```

### 5.2 내부 저장 구조 예시

```json
{
  "mappingId": "map-backend-junior-text-001",
  "inputType": "TEXT",
  "matchType": "TEXT_HASH",
  "matchValue": "sha256:4f7a8d2e...",
  "fixtureKey": "fixture-backend-junior-001",
  "title": "백엔드 주니어 텍스트 샘플",
  "createdAt": "2026-05-22T17:00:00+09:00",
  "active": true
}
```

```json
{
  "fixtureKey": "fixture-backend-junior-001",
  "version": "v1",
  "score": 78,
  "summary": "백엔드 중심 경험은 분명하지만 성과 수치가 더 필요합니다.",
  "strengths": [
    "Spring Boot API 구현 경험이 보입니다.",
    "예외 처리와 계층 분리 경험이 드러납니다."
  ],
  "improvements": [
    "프로젝트 결과를 수치로 보강해 주세요.",
    "트래픽 또는 성능 개선 경험을 더 구체화해 주세요."
  ],
  "keywords": [
    "Spring Boot",
    "REST API",
    "Validation"
  ],
  "sourceType": "FIXTURE",
  "locale": "ko-KR",
  "createdAt": "2026-05-22T17:00:00+09:00"
}
```

## 6. 저장 위치 권장안

### 6.1 1순위: 정적 fixture 파일

- `backend/src/main/resources/fixtures/resume-mappings.json`
- `backend/src/main/resources/fixtures/analysis-results.json`

장점:
- 구현이 가장 빠르다.
- 리뷰와 테스트가 쉽다.

### 6.2 2순위: H2 테스트 DB

테이블 예시:

- `resume_fixture_mapping`
- `fixture_analysis`

장점:
- 조회 조건과 예외 처리를 DB처럼 검증할 수 있다.

## 7. 조회 규칙

1. 입력 타입 확인
2. 텍스트 또는 파일 추출 결과 정규화
3. `matchType` 기준으로 `ResumeFixtureMapping` 조회
4. 연결된 `fixtureKey`로 `FixtureAnalysis` 조회
5. 없으면 `FIXTURE_NOT_FOUND`

## 8. 에러 처리 기준

| 상황 | 에러 코드 |
|---|---|
| 지원하지 않는 파일 형식 | `UNSUPPORTED_FILE_TYPE` |
| 파일 텍스트 추출 실패 | `FILE_TEXT_EXTRACTION_FAILED` |
| 매핑 없음 | `FIXTURE_NOT_FOUND` |
| 매핑은 있지만 결과 본문 없음 | `FIXTURE_NOT_FOUND` |

## 9. 구현 메모

- Java DTO는 `ResumeFixtureMapping`, `FixtureAnalysis`, `DiagnosisResultResponse`로 나눈다.
- Repository는 처음에는 JSON 로더 기반으로 시작하고, 나중에 H2/JPA로 교체한다.
- 파일명 매핑은 빠른 시연용이고, 장기적으로는 `TEXT_HASH` 중심으로 통일한다.
