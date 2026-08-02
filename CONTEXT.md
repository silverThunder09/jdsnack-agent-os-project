# JDSnack Context

JDSnack의 이력서·JD 분석 결과를 일관되게 설계하기 위한 제품 도메인 용어집이다. 사용자 점수와 AI 응답 자체의 품질을 구분한다.

## Analysis

**Analysis History**:
사용자가 제출한 하나의 입력 사본으로 생성된 분석 실행과 그 결과의 영속 기록이다. 재시도는 같은 입력 사본을 사용하더라도 새 Analysis History를 만든다.
_Avoid_: analysis session, analysis record

**AI Quality Assessment**:
성공한 Analysis History 하나에 귀속되는 AI 응답 품질 평가 결과다. 이력서·JD 적합도나 ATS처럼 사용자를 평가하는 점수가 아니다.
_Avoid_: AI score, user quality score, common quality grade

**Quality Rule Set**:
AI Quality Assessment를 계산하는 이름 있는 결정론적 검증 기준 묶음이다. 같은 버전과 같은 분석 결과에는 항상 같은 평가 결과를 낸다.
_Avoid_: evaluator prompt, random quality check

**Evidence Citation**:
분석 결과의 강점·부족 역량·제안을 뒷받침하기 위해 입력 사본의 이력서 또는 JD에서 인용한 원문 근거다. 각 주장에는 하나 이상의 인용문을 배열로 두며, 인용문은 지정한 출처 원문에서 그대로 확인할 수 있어야 한다.
_Avoid_: free-form rationale, unverifiable source note

사용자 결과 화면에서는 기본 접힘 상태의 `근거 보기`로 출처와 인용문을 확인할 수 있다.

**Analysis Execution Version**:
한 Analysis History를 생성할 때 컴포넌트별로 사용한 모델·프롬프트·평가 기준의 식별자 묶음이다. 이력서 진단, JD 매칭, 품질 평가를 각각 기록하며 사용자 평가 점수가 아니다.
_Avoid_: user-facing AI version, quality score version

**Version Identifier**:
분석 컴포넌트의 모델 또는 프롬프트 정책을 구분하는 서버 설정의 명시적 이름이다. Git 커밋 SHA나 프롬프트 원문을 대신하지 않는다.
_Avoid_: git SHA, prompt body

**Quality Status**:
AI Quality Assessment 점수를 사용자가 이해할 수 있게 구간으로 나타낸 상태다. `검증 양호`는 90점 이상, `일부 확인 필요`는 70점부터 89점, `재분석 권장`은 69점 이하이며, 낮은 상태는 결과를 차단하지 않는다.
_Avoid_: invalid result, failed analysis

**Quality Metric**:
Quality Rule Set 안에서 AI 응답 품질의 한 측면을 0점부터 100점까지 측정하는 기준이다. 점수는 기대한 검증 수 중 통과한 비율로 계산하며, `quality-v1`은 응답 형식 준수, 원문 근거 연결성, 결과 완성도로 구성한다.
_Avoid_: user score category, analysis feature score

**Result Unavailable**:
분석 이력의 내부 상태가 `FAILED`일 때 사용자에게 보여 주는 결과 미생성 상태다. 입력 사본은 보존되고, 원인에 맞는 재시도 또는 입력 보완 행동을 제공하며 품질점수는 표시하지 않는다.
_Avoid_: analysis failed, low quality
