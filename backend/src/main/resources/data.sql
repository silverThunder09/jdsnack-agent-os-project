    MERGE INTO fixture_analysis (
        fixture_key,
        version,
        score,
        summary,
        strengths_json,
        improvements_json,
        keywords_json,
        locale,
        created_at
    ) KEY (fixture_key) VALUES (
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

    MERGE INTO resume_fixture_mapping (
        mapping_id,
        input_type,
        match_type,
        match_value,
        fixture_key,
        title,
        active,
        created_at
    ) KEY (mapping_id) VALUES
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
