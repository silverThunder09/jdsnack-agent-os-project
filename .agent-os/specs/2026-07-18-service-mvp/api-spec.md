# Service MVP API 계약

## 공통

- 보호 API는 Google 로그인으로 발급된 내부 세션을 요구한다.
- 성공 응답은 기존 `ApiResponse<T>` 래퍼를 사용한다.
- Entity는 응답으로 직접 노출하지 않고 전용 response DTO로 변환한다.
- 타인 소유 또는 삭제된 이력은 동일한 `ANALYSIS_HISTORY_NOT_FOUND` 계열 오류로 처리해 존재 여부를 숨긴다.

## 저장소 계약

- Service MVP의 서비스 영속 저장소 방향은 [ADR-014 PostgreSQL](../../adr/adr-014-postgresql.md)을 따른다.
- PostgreSQL의 구체적인 스키마·migration·운영 연결·복구 방식은 관련 technical ADR과 구현 티켓에서 확정한다.
- 테스트는 H2 또는 fixture를 사용할 수 있지만, 서비스 재시작 후에도 사용자·분석 이력이 보존되는 운영 저장소 계약을 대체하지 않는다.

## 인증

### `GET /api/auth/google/start`

Google authorization endpoint로 redirect한다. client secret은 서버 설정에서만 사용한다.

### `GET /api/auth/google/callback?code={code}&state={state}`

서버가 code/state를 검증하고 provider subject를 내부 사용자에 연결한 뒤 내부 세션을 생성한다. 성공 시 프론트의 인증 완료 경로로 redirect한다.

### `GET /api/auth/session`

현재 내부 세션 상태를 반환한다. 세션이 없으면 `200`과 `authenticated: false`를 반환하며, 인증된 경우 provider token이 아닌 내부 사용자 ID·이메일·표시 이름만 반환한다.

## 분석 이력 생성

### `POST /api/analysis-histories`

정규화된 기존 이력서 텍스트와 JD 입력을 받아 분석을 실행하고 새 이력을 생성한다. PDF/DOCX 업로드는 기존 텍스트 추출 경계를 먼저 사용하며, 이 API에는 원본 파일을 영속 저장하지 않는다.

요청:

```json
{
  "resumeText": "제출 당시 이력서 텍스트",
  "jd": {
    "inputType": "TEXT",
    "text": "제출 당시 JD 본문",
    "sourceUrl": null,
    "sourceSite": null
  }
}
```

`inputType`은 `TEXT` 또는 `SARAMIN_URL`이다. URL 입력은 서버가 기존 JD fetch 계약으로 본문을 수집한 뒤 `text`와 `sourceUrl`을 모두 스냅샷에 기록한다. 실제 요청에서는 URL 입력 시 `sourceUrl`을 보내고 `text`는 서버가 채운다.

성공 응답 예:

```json
{
  "data": {
    "id": "history-uuid",
    "status": "SUCCEEDED",
    "createdAt": "2026-07-18T12:00:00Z",
    "result": {
      "diagnosis": {},
      "match": {}
    }
  }
}
```

AI 실패 응답은 HTTP 오류만 반환하지 않고 `FAILED` 이력의 ID와 상태를 함께 반환한다.

## 이력 조회

### `GET /api/analysis-histories`

현재 사용자 소유 이력을 최신순으로 반환한다. 목록에는 `id`, `status`, `createdAt`, JD 제목/출처 요약, 결과 요약만 포함한다.

### `GET /api/analysis-histories/{historyId}`

현재 사용자 소유 이력의 입력 스냅샷, JD 본문·출처 URL, 상태, 결과 또는 실패 사유를 반환한다.

## 재시도

### `POST /api/analysis-histories/{historyId}/retry`

기존 이력의 저장된 이력서 텍스트와 JD 본문을 사용해 새 분석 이력을 생성한다. URL fetch는 호출하지 않는다. 요청 body는 없다.

응답은 생성된 새 이력의 `id`, `status`, `createdAt`과 결과를 반환한다. 기존 이력은 변경하지 않는다.

## 삭제

### `DELETE /api/analysis-histories/{historyId}`

현재 사용자 소유 이력과 연결된 입력 스냅샷·JD·결과를 하나의 트랜잭션 경계에서 삭제한다. 성공 시 `204 No Content`를 반환한다. 휴지통·복구·지연 삭제는 제공하지 않는다.

## 오류

| 상황 | HTTP | 코드 예시 |
|---|---:|---|
| 세션 없음 | 401 | `AUTHENTICATION_REQUIRED` |
| 입력 검증 실패 | 400 | `INVALID_ANALYSIS_INPUT` |
| JD 수집 실패 | 422 | `JD_INPUT_UNAVAILABLE` |
| AI 실행/결과 검증 실패 | 200/202 + `FAILED` record | `ANALYSIS_FAILED` |
| 이력 없음/타인 소유 | 404 | `ANALYSIS_HISTORY_NOT_FOUND` |
