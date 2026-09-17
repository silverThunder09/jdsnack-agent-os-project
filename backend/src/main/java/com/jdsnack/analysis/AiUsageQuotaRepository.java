package com.jdsnack.analysis;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.Date;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;
@Repository
public class AiUsageQuotaRepository {
    private static final Object H2_ROW_LOCK = new Object();
    private final JdbcTemplate jdbcTemplate;
    private final boolean postgres;
    public AiUsageQuotaRepository(JdbcTemplate jdbcTemplate) { this.jdbcTemplate = jdbcTemplate; this.postgres = isPostgres(jdbcTemplate.getDataSource()); }
    public AiUsageReservation reserve(String userId, LocalDate usageDate, int dailyLimit, String historyId, String endpoint, long retryAfterSeconds, java.time.OffsetDateTime resetAt) {
        ensureQuotaRow(userId, usageDate, dailyLimit, endpoint);
        int updated = jdbcTemplate.update(
                "UPDATE ai_usage_quota SET used_count = used_count + 1, updated_at = CURRENT_TIMESTAMP "
                        + "WHERE user_id = ? AND usage_date = ? AND used_count < daily_limit",
                userId,
                Date.valueOf(usageDate)
        );
        QuotaRow row = findQuota(userId, usageDate).orElseThrow();
        if (updated == 0) {
            return new AiUsageReservation(
                    null,
                    false,
                    row.dailyLimit(),
                    row.usedCount(),
                    Math.max(0, row.dailyLimit() - row.usedCount()),
                    resetAt,
                    retryAfterSeconds
            );
        }
        String usageId = UUID.randomUUID().toString();
        int remaining = Math.max(0, row.dailyLimit() - row.usedCount());
        jdbcTemplate.update(
                "INSERT INTO ai_usage_ledger (usage_id, user_id, usage_date, history_id, endpoint, daily_limit, "
                        + "used_count, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                usageId,
                userId,
                Date.valueOf(usageDate),
                historyId,
                endpoint,
                row.dailyLimit(),
                row.usedCount(),
                "RESERVED",
                Timestamp.from(Instant.now()),
                Timestamp.from(Instant.now())
        );
        return new AiUsageReservation(
                usageId,
                true,
                row.dailyLimit(),
                row.usedCount(),
                remaining,
                resetAt,
                retryAfterSeconds
        );
    }
    public void markRunning(String usageId) { updateStatus(usageId, "RUNNING"); }
    public void markSucceeded(String usageId, AnalysisExecutionVersion diagnosisVersion, AnalysisExecutionVersion matchVersion) {
        jdbcTemplate.update(
                "UPDATE ai_usage_ledger SET status = ?, diagnosis_model_name = ?, diagnosis_prompt_version = ?, "
                        + "match_model_name = ?, match_prompt_version = ?, updated_at = CURRENT_TIMESTAMP WHERE usage_id = ?",
                "SUCCEEDED",
                diagnosisVersion == null ? null : diagnosisVersion.modelName(),
                diagnosisVersion == null ? null : diagnosisVersion.promptVersion(),
                matchVersion == null ? null : matchVersion.modelName(),
                matchVersion == null ? null : matchVersion.promptVersion(),
                usageId
        );
    }
    public void markFailed(String usageId, AnalysisExecutionVersion diagnosisVersion, String failureCode) {
        jdbcTemplate.update(
                "UPDATE ai_usage_ledger SET status = ?, diagnosis_model_name = ?, diagnosis_prompt_version = ?, "
                        + "failure_code = ?, updated_at = CURRENT_TIMESTAMP WHERE usage_id = ?",
                "FAILED",
                diagnosisVersion == null ? null : diagnosisVersion.modelName(),
                diagnosisVersion == null ? null : diagnosisVersion.promptVersion(),
                failureCode,
                usageId
        );
    }
    private void updateStatus(String usageId, String status) { jdbcTemplate.update("UPDATE ai_usage_ledger SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE usage_id = ?", status, usageId); }
    private void ensureQuotaRow(String userId, LocalDate usageDate, int dailyLimit, String endpoint) {
        if (postgres) {
            jdbcTemplate.update(
                    "INSERT INTO ai_usage_quota (user_id, usage_date, daily_limit, used_count, endpoint, created_at, updated_at) "
                            + "VALUES (?, ?, ?, 0, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) "
                            + "ON CONFLICT (user_id, usage_date) DO NOTHING",
                    userId,
                    Date.valueOf(usageDate),
                    dailyLimit,
                    endpoint
            );
            return;
        }
        synchronized (H2_ROW_LOCK) {
            jdbcTemplate.update(
                    "INSERT INTO ai_usage_quota (user_id, usage_date, daily_limit, used_count, endpoint, created_at, updated_at) "
                            + "SELECT ?, ?, ?, 0, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP "
                            + "WHERE NOT EXISTS (SELECT 1 FROM ai_usage_quota WHERE user_id = ? AND usage_date = ?)",
                    userId,
                    Date.valueOf(usageDate),
                    dailyLimit,
                    endpoint,
                    userId,
                    Date.valueOf(usageDate)
            );
        }
    }
    private Optional<QuotaRow> findQuota(String userId, LocalDate usageDate) {
        return jdbcTemplate.query(
                        "SELECT daily_limit, used_count FROM ai_usage_quota WHERE user_id = ? AND usage_date = ?",
                        (resultSet, rowNum) -> new QuotaRow(
                                resultSet.getInt("daily_limit"),
                                resultSet.getInt("used_count")
                        ),
                        userId,
                        Date.valueOf(usageDate)
                )
                .stream()
                .findFirst();
    }
    private record QuotaRow(int dailyLimit, int usedCount) {}
    private boolean isPostgres(DataSource dataSource) {
        if (dataSource == null) {
            throw new IllegalStateException("AI usage quota requires a configured DataSource");
        }
        try (Connection connection = dataSource.getConnection()) {
            return "PostgreSQL".equalsIgnoreCase(connection.getMetaData().getDatabaseProductName());
        } catch (SQLException exception) {
            throw new IllegalStateException("Could not determine database product for AI usage quota", exception);
        }
    }
}
