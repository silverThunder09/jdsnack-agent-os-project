# ADR-001: AI readiness gate 운영

## Context

AI 작업 문서의 링크·신선도·정적 eval 구조가 조용히 낡으면 agent가 잘못된 파일을 따라갈 수 있습니다.

## Decision

`python3 scripts/check-ai-readiness.py`를 결정론적 gate로 유지하고, `.agent-os/ai-readiness.yml`의 75점 threshold와 30일 drift 기준을 적용합니다. 모델 eval은 비용이 발생하므로 필요할 때만 로컬 Codex 세션에서 실행합니다.

## Consequences

- 문서 링크와 module context 문제는 모델 호출 없이 CI와 pre-commit에서 잡습니다.
- 실제 agent 품질·토큰·재작업률은 성공한 eval 결과와 PR telemetry가 연결될 때만 수치화합니다.
