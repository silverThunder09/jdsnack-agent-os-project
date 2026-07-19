package com.jdsnack.analysis;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.Timestamp;
import java.util.List;
import java.util.Optional;

@Repository
public class AnalysisHistoryRepository {

    private final JdbcTemplate jdbcTemplate;

    public AnalysisHistoryRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public AnalysisHistory save(AnalysisHistory history) {
        jdbcTemplate.update(
                """
                        INSERT INTO analysis_history (
                            history_id,
                            user_id,
                            snapshot_id,
                            status,
                            diagnosis_json,
                            match_json,
                            failure_code,
                            failure_message,
                            created_at,
                            updated_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                history.id(),
                history.userId(),
                history.snapshotId(),
                history.status().name(),
                history.diagnosisJson(),
                history.matchJson(),
                history.failureCode(),
                history.failureMessage(),
                Timestamp.from(history.createdAt()),
                Timestamp.from(history.updatedAt())
        );
        return findByIdAndUserId(history.id(), history.userId()).orElseThrow();
    }

    public Optional<AnalysisHistory> findByIdAndUserId(String historyId, String userId) {
        return jdbcTemplate.query(
                        """
                                SELECT history_id,
                                       user_id,
                                       snapshot_id,
                                       status,
                                       diagnosis_json,
                                       match_json,
                                       failure_code,
                                       failure_message,
                                       created_at,
                                       updated_at
                                FROM analysis_history
                                WHERE history_id = ? AND user_id = ?
                                """,
                        rowMapper(),
                        historyId,
                        userId
                )
                .stream()
                .findFirst();
    }

    public List<AnalysisHistory> findAllByUserId(String userId) {
        return jdbcTemplate.query(
                """
                        SELECT history_id,
                               user_id,
                               snapshot_id,
                               status,
                               diagnosis_json,
                               match_json,
                               failure_code,
                               failure_message,
                               created_at,
                               updated_at
                        FROM analysis_history
                        WHERE user_id = ?
                        ORDER BY created_at DESC, history_id DESC
                        """,
                rowMapper(),
                userId
        );
    }

    public AnalysisHistory markSucceeded(
            String historyId,
            String userId,
            String diagnosisJson,
            String matchJson
    ) {
        jdbcTemplate.update(
                "UPDATE analysis_history SET status = ?, diagnosis_json = ?, match_json = ?, "
                        + "failure_code = NULL, failure_message = NULL, updated_at = CURRENT_TIMESTAMP "
                        + "WHERE history_id = ? AND user_id = ?",
                AnalysisHistoryStatus.SUCCEEDED.name(),
                diagnosisJson,
                matchJson,
                historyId,
                userId
        );
        return findByIdAndUserId(historyId, userId).orElseThrow();
    }

    public AnalysisHistory markFailed(
            String historyId,
            String userId,
            String failureCode,
            String failureMessage
    ) {
        jdbcTemplate.update(
                "UPDATE analysis_history SET status = ?, failure_code = ?, failure_message = ?, "
                        + "updated_at = CURRENT_TIMESTAMP WHERE history_id = ? AND user_id = ?",
                AnalysisHistoryStatus.FAILED.name(),
                failureCode,
                failureMessage,
                historyId,
                userId
        );
        return findByIdAndUserId(historyId, userId).orElseThrow();
    }

    public boolean deleteByIdAndUserId(String historyId, String userId) {
        return jdbcTemplate.update(
                "DELETE FROM analysis_history WHERE history_id = ? AND user_id = ?",
                historyId,
                userId
        ) > 0;
    }

    private org.springframework.jdbc.core.RowMapper<AnalysisHistory> rowMapper() {
        return (resultSet, rowNum) -> new AnalysisHistory(
                resultSet.getString("history_id"),
                resultSet.getString("user_id"),
                resultSet.getString("snapshot_id"),
                AnalysisHistoryStatus.valueOf(resultSet.getString("status")),
                resultSet.getString("diagnosis_json"),
                resultSet.getString("match_json"),
                resultSet.getString("failure_code"),
                resultSet.getString("failure_message"),
                resultSet.getTimestamp("created_at").toInstant(),
                resultSet.getTimestamp("updated_at").toInstant()
        );
    }
}
