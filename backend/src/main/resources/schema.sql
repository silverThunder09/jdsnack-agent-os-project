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

CREATE TABLE IF NOT EXISTS analysis_input_snapshot (
    snapshot_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    resume_text TEXT NOT NULL,
    jd_input_type VARCHAR(32) NOT NULL,
    jd_text TEXT NOT NULL,
    jd_source_url VARCHAR(2048),
    jd_source_site VARCHAR(64),
    jd_fetch_mode VARCHAR(64),
    created_at TIMESTAMP NOT NULL,
    CONSTRAINT fk_analysis_input_snapshot_user
        FOREIGN KEY (user_id) REFERENCES app_user(user_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_analysis_input_snapshot_user_created
    ON analysis_input_snapshot (user_id, created_at);

CREATE TABLE IF NOT EXISTS analysis_history (
    history_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    snapshot_id VARCHAR(36) NOT NULL,
    status VARCHAR(16) NOT NULL,
    diagnosis_json TEXT,
    diagnosis_model_name VARCHAR(255),
    diagnosis_prompt_version VARCHAR(255),
    match_json TEXT,
    match_model_name VARCHAR(255),
    match_prompt_version VARCHAR(255),
    failure_code VARCHAR(64),
    failure_message VARCHAR(1000),
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    CONSTRAINT fk_analysis_history_user
        FOREIGN KEY (user_id) REFERENCES app_user(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_analysis_history_snapshot
        FOREIGN KEY (snapshot_id) REFERENCES analysis_input_snapshot(snapshot_id) ON DELETE CASCADE
);

ALTER TABLE analysis_history ADD COLUMN IF NOT EXISTS diagnosis_model_name VARCHAR(255);
ALTER TABLE analysis_history ADD COLUMN IF NOT EXISTS diagnosis_prompt_version VARCHAR(255);
ALTER TABLE analysis_history ADD COLUMN IF NOT EXISTS match_model_name VARCHAR(255);
ALTER TABLE analysis_history ADD COLUMN IF NOT EXISTS match_prompt_version VARCHAR(255);

CREATE INDEX IF NOT EXISTS idx_analysis_history_user_created
    ON analysis_history (user_id, created_at);

CREATE TABLE IF NOT EXISTS analysis_feedback (
    feedback_id VARCHAR(36) PRIMARY KEY,
    history_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    rating VARCHAR(16) NOT NULL,
    comment VARCHAR(500),
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    CONSTRAINT uq_analysis_feedback_history_user UNIQUE (history_id, user_id),
    CONSTRAINT fk_analysis_feedback_history
        FOREIGN KEY (history_id) REFERENCES analysis_history(history_id) ON DELETE CASCADE,
    CONSTRAINT fk_analysis_feedback_user
        FOREIGN KEY (user_id) REFERENCES app_user(user_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_analysis_feedback_history
    ON analysis_feedback (history_id);

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
    strengths_json TEXT NOT NULL,
    improvements_json TEXT NOT NULL,
    keywords_json TEXT,
    locale VARCHAR(16) NOT NULL,
    created_at TIMESTAMP NOT NULL
);
