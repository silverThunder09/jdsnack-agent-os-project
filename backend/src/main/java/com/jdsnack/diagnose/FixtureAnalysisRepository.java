package com.jdsnack.diagnose;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.io.IOException;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import java.util.Optional;

@Repository
public class FixtureAnalysisRepository {

    private static final TypeReference<List<String>> STRING_LIST_TYPE = new TypeReference<>() {
    };

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    public FixtureAnalysisRepository(JdbcTemplate jdbcTemplate, ObjectMapper objectMapper) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
    }

    public Optional<FixtureAnalysis> findByInputTypeAndMatchValue(
            UploadedResumeType inputType,
            String matchValue
    ) {
        List<FixtureAnalysis> fixtureAnalyses = jdbcTemplate.query(
                """
                        SELECT fa.fixture_key,
                               fa.score,
                               fa.summary,
                               fa.strengths_json,
                               fa.improvements_json
                        FROM resume_fixture_mapping rfm
                        JOIN fixture_analysis fa
                          ON fa.fixture_key = rfm.fixture_key
                        WHERE rfm.input_type = ?
                          AND rfm.match_type = 'TEXT_HASH'
                          AND rfm.match_value = ?
                          AND rfm.active = TRUE
                        """,
                (resultSet, rowNum) -> mapFixtureAnalysis(resultSet),
                inputType.name(),
                matchValue
        );

        return fixtureAnalyses.stream().findFirst();
    }

    private FixtureAnalysis mapFixtureAnalysis(ResultSet resultSet) throws SQLException {
        try {
            return new FixtureAnalysis(
                    resultSet.getString("fixture_key"),
                    resultSet.getInt("score"),
                    resultSet.getString("summary"),
                    objectMapper.readValue(resultSet.getString("strengths_json"), STRING_LIST_TYPE),
                    objectMapper.readValue(resultSet.getString("improvements_json"), STRING_LIST_TYPE)
            );
        } catch (IOException exception) {
            throw new IllegalStateException("Failed to parse fixture analysis JSON", exception);
        }
    }
}
