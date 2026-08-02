-- 시드 삽입은 H2와 PostgreSQL 양쪽에서 동작해야 한다(ADR-019).
--
-- 이전에는 H2 전용 `MERGE INTO ... KEY (...)`를 썼다. PostgreSQL의 MERGE는
-- `USING ... ON ... WHEN MATCHED` 형태라 이 문법을 받지 않으며, PostgreSQL 15
-- 이전에는 MERGE 자체가 없다.
--
-- `INSERT ... ON CONFLICT`도 대안이 아니다. PostgreSQL은 지원하지만 H2가 거부한다
-- (ScriptStatementFailedException으로 확인).
--
-- 따라서 두 DBMS가 모두 지원하는 표준 SQL만 쓴다. 먼저 해당 시드 행을 지우고 다시
-- 넣어 재실행 시 멱등성을 유지하며, 파일 내용이 항상 최종 상태가 된다(기존 MERGE와
-- 동일한 의미). 두 테이블 모두 외래키 참조가 없어 삭제 순서에 제약이 없다.

DELETE FROM resume_fixture_mapping WHERE mapping_id IN (
    'map-text-backend-junior-001',
    'map-pdf-backend-junior-001',
    'map-docx-backend-junior-001'
);

DELETE FROM fixture_analysis WHERE fixture_key = 'fixture-backend-junior-001';

    INSERT INTO fixture_analysis (
        fixture_key,
        version,
        score,
        summary,
        strengths_json,
        improvements_json,
        keywords_json,
        locale,
        created_at
    ) VALUES (
        'fixture-backend-junior-001',
        'v1',
        78,
        '백엔드 중심 경험은 분명하지만 성과 수치가 더 필요합니다.',
        '["Spring Boot API 구현 경험이 보입니다.","예외 처리와 계층 분리 경험이 드러납니다."]',
        '["프로젝트 결과를 수치로 보강해 주세요.","트래픽 또는 성능 개선 경험을 더 구체화해 주세요."]',
        '["Spring Boot","REST API","Validation"]',
        'ko-KR',
        TIMESTAMP '2026-05-22 17:00:00'
    );

    INSERT INTO resume_fixture_mapping (
        mapping_id,
        input_type,
        match_type,
        match_value,
        fixture_key,
        title,
        active,
        created_at
    ) VALUES
    (
        'map-text-backend-junior-001',
        'TEXT',
        'TEXT_HASH',
        'sha256:6e504cbf1fd4f86ddc989691e34cea6aee848cbed0337f3bc5d6e30ce76f09b8',
        'fixture-backend-junior-001',
        '백엔드 주니어 텍스트 샘플',
        TRUE,
        TIMESTAMP '2026-05-22 17:00:00'
    ),
    (
        'map-pdf-backend-junior-001',
        'PDF',
        'TEXT_HASH',
        'sha256:6e504cbf1fd4f86ddc989691e34cea6aee848cbed0337f3bc5d6e30ce76f09b8',
        'fixture-backend-junior-001',
        '백엔드 주니어 PDF 샘플',
        TRUE,
        TIMESTAMP '2026-05-22 17:00:00'
    ),
    (
        'map-docx-backend-junior-001',
        'DOCX',
        'TEXT_HASH',
        'sha256:6e504cbf1fd4f86ddc989691e34cea6aee848cbed0337f3bc5d6e30ce76f09b8',
        'fixture-backend-junior-001',
        '백엔드 주니어 DOCX 샘플',
        TRUE,
        TIMESTAMP '2026-05-22 17:00:00'
    );
