CREATE TABLE IF NOT EXISTS resume_fixture_mapping (
    mapping_id VARCHAR(64) PRIMARY KEY,
    input_type VARCHAR(16) NOT NULL,
    match_type VARCHAR(32) NOT NULL,
    match_value VARCHAR(255) NOT NULL,
    fixture_key VARCHAR(64) NOT NULL,
    title VARCHAR(255),
    active BOOLEAN NOT NULL,
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS fixture_analysis (
    fixture_key VARCHAR(64) PRIMARY KEY,
    version VARCHAR(16) NOT NULL,
    score INTEGER NOT NULL,
    summary VARCHAR(1000) NOT NULL,
    strengths_json CLOB NOT NULL,
    improvements_json CLOB NOT NULL,
    keywords_json CLOB,
    locale VARCHAR(16) NOT NULL,
    created_at TIMESTAMP NOT NULL
);
