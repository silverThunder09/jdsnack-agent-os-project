CREATE TABLE IF NOT EXISTS app_user (
    user_id VARCHAR(36) PRIMARY KEY,
    provider VARCHAR(32) NOT NULL,
    provider_subject VARCHAR(255) NOT NULL,
    email VARCHAR(320) NOT NULL,
    display_name VARCHAR(255),
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    CONSTRAINT uq_app_user_provider_subject UNIQUE (provider, provider_subject)
);

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
