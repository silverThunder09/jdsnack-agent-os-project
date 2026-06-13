# 모의 면접 질문 생성 계획

## Summary

이력서(선택적으로 직무·JD 맥락)를 기반으로 예상 면접 질문을 생성하는 기능을 추가한다. 기존 `diagnose`/`match`와 동형(이력서 → Gemini → 구조화 응답)이므로 그 패턴을 그대로 재사용한다.

## 변경 범위

- 새 active spec 추가, 기존 JD-match spec archive 이동, `.agent-os/standards/index.yml`·`AGENTS.md` active spec 갱신(이 문서 PR).
- 구현(별도 Codex 작업): 백엔드 `interview/` 패키지, 프론트 면접 질문 섹션.

## 구현 지침 (Codex)

- 백엔드: `backend/src/main/java/com/jdsnack/match/` 구조를 본떠 `interview/` 패키지를 만든다.
  - `InterviewController`(`POST /api/interview/preview`), `InterviewService`(검증 + provider 선택), `InterviewProvider` 인터페이스와 `Stub/Fixture/Gemini` 구현.
  - 모드 분기는 기존 `DiagnosisMode`(`JDSNACK_DIAGNOSIS_MODE`)와 `MatchPreviewService` 분기 방식을 재사용한다.
  - 응답은 `common/ApiResponse` 래퍼를 따르고, `common/ErrorCode`에 `MOCK_INTERVIEW_NOT_ENABLED`, `INTERVIEW_QUESTION_GENERATION_FAILED`를 추가한다.
  - Gemini provider는 `GeminiMatchPreviewProvider`의 호출·JSON 파싱·펜스 제거 패턴을 따르고 프롬프트만 면접 질문 생성용으로 작성한다.
  - 이력서 길이 검증(약 50~10000자)은 기존 서비스 검증 규칙을 재사용한다.
- 프론트: `services/api.ts`에 생성 호출 함수, `hooks`에 상태 훅, `types/diagnosis.ts`에 요청/응답·Outcome 타입, 리포트 단계 뒤 질문 카드 섹션을 추가한다.
- 검증: 단위 테스트(서비스 검증/모드 분기), 프론트 단위 테스트, e2e는 route mock으로 UI 연결 흐름 고정. `ai-local` 실호출은 로컬 수동 검증으로만 수행한다.

## 제외 범위

- 기존 `diagnose`/`match`/`jd/fetch` 계약 변경
- 새 외부 사이트 수집, 브라우저 렌더링 수집
- 운영 배포 플랫폼 확정 및 자동 배포 트리거
- 질문 난이도 조절·답변 평가 등 후속 고도화

## 컨테이너 운영 기준

- 로컬 개발/검증은 `compose.local.yaml`에서 `build:`로 소스 이미지를 빌드한다.
- 배포/운영 실행은 `compose.prod.yaml`에서 `image:`로 registry 이미지를 pull한다.
- 현재 EC2 수동 배포와 운영 배포 검증은 아직 실행하지 않았다.
