# Work Start Checkpoint

## Target Spec
- 대상 spec: 활성 Feature 없음. 하네스 문서와 자율 큐 CI 운영 수정입니다.

## Risk Level
- `Standard`: 제품 신호 대기의 종료 코드와 운영 문서를 수정합니다. 고정 위험도 라벨은 `review-risk.ps1`의 결과를 따릅니다.
- 판단 이유: 자동 디스패치 허용 조건과 리뷰·병합 게이트는 유지합니다.

## Change Scope
- 이번 작업에서 바꾸는 것: 기본 리뷰어·위험도·PR 역할의 문서 드리프트, 정상 제품 판단 대기의 CI 결과와 표시, 회귀 테스트.
- 이번 작업에서 바꾸지 않는 것: 서비스 API/UI, 제품 큐 조건, branch protection, reviewer 모델 배정.

## Read Scope
- 반드시 읽을 문서/폴더: 하네스·완료·PR·리뷰·CI 운영 문서, 자율 루프 coordinator·workflow·테스트.
- 필요할 때만 읽을 문서/폴더: 최근 실패 workflow 로그, PR 계약 검사.

## Do Not Read
- 기본 탐색 제외: archive, 의존성·빌드 산출물, `.env` 내용.
- 예외적으로만 확인할 범위: 실패 원인과 연결된 특정 로그.

## Test Plan
- 로컬 테스트: 정상 대기 exit 20 재현 후 exit 0·notice·summary·무디스패치 확인, 오류 exit 20 유지, Docs Harness·Workflow CI.
- 수동 검증: 최신 main의 실제 GitHub 보호 규칙·runner·최근 실패 원인 확인.
- CI 기대 항목: Validate PR contract, Validate Agent OS docs, Workflow CI contract, PR CI Gate, Codex review.

## PR Scope
- PR 주 목적: 자율 루프의 제품 판단 대기를 오류와 구분하고 같은 운영 계약의 문서를 최신화합니다.
- 같은 PR에 포함할 항목: 문서·CI 수정과 직접 대응하는 회귀 테스트. 사용자 요청에 따라 하나의 운영 PR로 제출합니다.
- 별도 PR로 분리할 항목: 서비스 기능과 제품 신호 신규 승인.
