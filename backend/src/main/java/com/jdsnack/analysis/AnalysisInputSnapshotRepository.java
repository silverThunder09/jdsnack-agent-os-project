package com.jdsnack.analysis;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.Timestamp;
import java.util.Optional;

@Repository
public class AnalysisInputSnapshotRepository {

    private final JdbcTemplate jdbcTemplate;

    public AnalysisInputSnapshotRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public AnalysisInputSnapshot save(AnalysisInputSnapshot snapshot) {
        jdbcTemplate.update(
                """
                        INSERT INTO analysis_input_snapshot (
                            snapshot_id,
                            user_id,
                            resume_text,
                            jd_input_type,
                            jd_text,
                            jd_source_url,
                            jd_source_site,
                            jd_fetch_mode,
                            created_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                snapshot.id(),
                snapshot.userId(),
                snapshot.resumeText(),
                snapshot.jdInputType().name(),
                snapshot.jdText(),
                snapshot.sourceUrl(),
                snapshot.sourceSite(),
                snapshot.fetchMode(),
                Timestamp.from(snapshot.createdAt())
        );
        return findByIdAndUserId(snapshot.id(), snapshot.userId()).orElseThrow();
    }

    public Optional<AnalysisInputSnapshot> findByIdAndUserId(String snapshotId, String userId) {
        return jdbcTemplate.query(
                        """
                                SELECT snapshot_id,
                                       user_id,
                                       resume_text,
                                       jd_input_type,
                                       jd_text,
                                       jd_source_url,
                                       jd_source_site,
                                       jd_fetch_mode,
                                       created_at
                                FROM analysis_input_snapshot
                                WHERE snapshot_id = ? AND user_id = ?
                                """,
                        (resultSet, rowNum) -> new AnalysisInputSnapshot(
                                resultSet.getString("snapshot_id"),
                                resultSet.getString("user_id"),
                                resultSet.getString("resume_text"),
                                JdInputType.valueOf(resultSet.getString("jd_input_type")),
                                resultSet.getString("jd_text"),
                                resultSet.getString("jd_source_url"),
                                resultSet.getString("jd_source_site"),
                                resultSet.getString("jd_fetch_mode"),
                                resultSet.getTimestamp("created_at").toInstant()
                        ),
                        snapshotId,
                        userId
                )
                .stream()
                .findFirst();
    }
}
