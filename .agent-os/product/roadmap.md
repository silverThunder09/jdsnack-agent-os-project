# 제품 로드맵 (Product Roadmap)

## 로드맵 읽기 규칙

기존 Phase 1~2.5는 제품 검증 이력입니다. 관련 구현 스펙은 archive에 보관하며, 현재 구현 루프는 `active_specs`와 실행 큐(`spec-queue.json`)를 기준으로 움직입니다.

## 제품 검증 이력

- Phase 1: 이력서 입력·검증·준비중 안내·Spring Boot/React 뼈대
- Phase 1.5: PDF/DOCX 업로드·텍스트 추출·fixture 분석
- Phase 1.6: JD 텍스트·링크 입력·비교 API 계약
- Phase 1.7: 사람인 HTML 수집·오탐 방지·안전한 외부 fetch
- Phase 2: Gemini 이력서 진단·구조화 응답
- Phase 2.5: Gemini JD 매칭·stub/fixture 롤백
- 기존 프론트 결과·문장·키워드·모의면접 preview

## 서비스 MVP

서비스 MVP는 기능 목록이 아니라 다음의 완전한 사용자 가치 흐름입니다.

`OAuth 1개 공급자 로그인 → 이력서·JD 입력 → 기존 AI 진단·JD 매칭 → 결과 저장 → 이력 조회·재시도·삭제`

사람인 이미지 OCR과 Service MVP는 구현·검증을 마치고 archive로 이동했습니다. 위 흐름 전체를 정의한 `2026-07-18-service-mvp` Feature Spec은 완료되었으며, 현재 active Spec은 마지막 "준비중" 분석 옵션을 해금하는 `2026-07-20-ats-score-format`입니다.

### 내부 수직 티켓

Service MVP는 수직 티켓 다섯 개(T1~T5)로 끝까지 관통했습니다. 완료된 티켓의 정의·의존성·검증 기록은 [plan.md](../archive/specs/2026-07-18-service-mvp/plan.md)가 정본입니다. 현재 active Spec의 티켓 정본은 [ats-score-format plan.md](../specs/2026-07-20-ats-score-format/plan.md)입니다.

## Post MVP

후보 설명은 [spec-backlog.md](spec-backlog.md)에, 실행 상태·우선순위·승격 조건은 [spec-queue.json](spec-queue.json)에 둡니다. 자동 판정 가능한 후보는 Feature Spec으로 자동 승격되고, 사람 판단이 필요한 후보만 중단 지점으로 알립니다.

## 실행 규칙

Feature Spec 운영 규칙(한 시점 1개 유지, 필수 문서 구성, 티켓 PR 절차, 큐 승격)은 [doc-lifecycle.md](../standards/doc-lifecycle.md)가 정본입니다.
