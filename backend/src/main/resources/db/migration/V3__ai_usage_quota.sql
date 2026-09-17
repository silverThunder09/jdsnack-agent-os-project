ALTER TABLE analysis_history ADD COLUMN idempotency_key VARCHAR(255);
CREATE UNIQUE INDEX uq_analysis_history_user_idempotency
    ON analysis_history (user_id, idempotency_key);
CREATE TABLE ai_usage_quota (
    user_id VARCHAR(36) NOT NULL,
    usage_date DATE NOT NULL,
    daily_limit INTEGER NOT NULL,
    used_count INTEGER NOT NULL,
    endpoint VARCHAR(128) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    CONSTRAINT pk_ai_usage_quota PRIMARY KEY (user_id, usage_date),
    CONSTRAINT fk_ai_usage_quota_user
        FOREIGN KEY (user_id) REFERENCES app_user(user_id) ON DELETE CASCADE
);
CREATE TABLE ai_usage_ledger (
    usage_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    usage_date DATE NOT NULL,
    history_id VARCHAR(36) NOT NULL,
    endpoint VARCHAR(128) NOT NULL,
    daily_limit INTEGER NOT NULL,
    used_count INTEGER NOT NULL,
    status VARCHAR(16) NOT NULL,
    failure_code VARCHAR(64),
    diagnosis_model_name VARCHAR(255),
    diagnosis_prompt_version VARCHAR(255),
    match_model_name VARCHAR(255),
    match_prompt_version VARCHAR(255),
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    CONSTRAINT fk_ai_usage_ledger_user
        FOREIGN KEY (user_id) REFERENCES app_user(user_id) ON DELETE CASCADE
);
CREATE INDEX idx_ai_usage_ledger_user_date
    ON ai_usage_ledger (user_id, usage_date, created_at);
