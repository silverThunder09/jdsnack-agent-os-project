# 제품 로드맵 (Product Roadmap)

## 로드맵 읽기 규칙

기존 Phase 1~2.5는 제품 검증 이력입니다. 관련 구현 스펙은 archive에 보관하며, 현재 구현 루프는 `active_specs`와 `pending_specs`를 기준으로만 움직입니다.

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

사람인 이미지 OCR은 구현·검증을 마치고 archive로 이동했습니다. 현재 위 흐름 전체를 정의한 `2026-07-18-service-mvp` Feature Spec이 유일한 active Spec입니다.

### 내부 수직 티켓

Service MVP Feature Spec은 다음 다섯 티켓으로 끝까지 관통합니다.

1. OAuth 로그인과 사용자 식별
2. 이력서·JD 입력과 저장 계약
3. 기존 AI 진단·JD 매칭 연결
4. 분석 결과 저장과 이력 조회
5. 재시도·삭제와 사용자 데이터 제어

## Post MVP

후보의 설명·선택 기준은 [spec-backlog.md](spec-backlog.md)에만 둡니다. 후보는 기획 확정 전에는 Feature Spec도 자동화 입력도 아닙니다.

## 실행 규칙

- 한 시점에는 Feature Spec 하나만 상세 문서로 유지합니다.
- Feature Spec은 requirements, acceptance criteria, test scenarios, API/UI 계약, traceability와 내부 티켓 계획을 가집니다.
- 티켓은 하나씩 PR·리뷰·머지하며, 마지막 티켓의 종단 간 검증이 끝나기 전에는 Feature Spec을 archive하지 않습니다.
- 후보 백로그에서 다음 Feature Spec으로의 승격은 `/grill-with-docs`로 범위를 확정한 뒤 사람이 시작합니다. 자동 승격하지 않습니다.
