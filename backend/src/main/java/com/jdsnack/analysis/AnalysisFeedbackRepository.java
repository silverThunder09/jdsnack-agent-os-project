package com.jdsnack.analysis;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.Timestamp;
import java.util.Optional;

@Repository
public class AnalysisFeedbackRepository {

    private final JdbcTemplate jdbcTemplate;

    public AnalysisFeedbackRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Optional<AnalysisFeedback> findByHistoryIdAndUserId(String historyId, String userId) {
        return jdbcTemplate.query(
                        """
                                SELECT feedback_id,
                                       history_id,
                                       user_id,
                                       rating,
                                       comment,
                                       created_at,
                                       updated_at
                                FROM analysis_feedback
                                WHERE history_id = ? AND user_id = ?
                                """,
                        rowMapper(),
                        historyId,
                        userId
                )
                .stream()
                .findFirst();
    }

    public AnalysisFeedback upsert(AnalysisFeedback feedback) {
        int updated = jdbcTemplate.update(
                "UPDATE analysis_feedback SET rating = ?, comment = ?, updated_at = ? "
                        + "WHERE history_id = ? AND user_id = ?",
                feedback.rating().name(),
                feedback.comment(),
                Timestamp.from(feedback.updatedAt()),
                feedback.historyId(),
                feedback.userId()
        );

        if (updated == 0) {
            jdbcTemplate.update(
                    """
                            INSERT INTO analysis_feedback (
                                feedback_id,
                                history_id,
                                user_id,
                                rating,
                                comment,
                                created_at,
                                updated_at
                            ) VALUES (?, ?, ?, ?, ?, ?, ?)
                            """,
                    feedback.id(),
                    feedback.historyId(),
                    feedback.userId(),
                    feedback.rating().name(),
                    feedback.comment(),
                    Timestamp.from(feedback.createdAt()),
                    Timestamp.from(feedback.updatedAt())
            );
        }

        return findByHistoryIdAndUserId(feedback.historyId(), feedback.userId()).orElseThrow();
    }

    public boolean deleteByHistoryIdAndUserId(String historyId, String userId) {
        return jdbcTemplate.update(
                "DELETE FROM analysis_feedback WHERE history_id = ? AND user_id = ?",
                historyId,
                userId
        ) > 0;
    }

    private org.springframework.jdbc.core.RowMapper<AnalysisFeedback> rowMapper() {
        return (resultSet, rowNum) -> new AnalysisFeedback(
                resultSet.getString("feedback_id"),
                resultSet.getString("history_id"),
                resultSet.getString("user_id"),
                AnalysisFeedbackRating.valueOf(resultSet.getString("rating")),
                resultSet.getString("comment"),
                resultSet.getTimestamp("created_at").toInstant(),
                resultSet.getTimestamp("updated_at").toInstant()
        );
    }
}
