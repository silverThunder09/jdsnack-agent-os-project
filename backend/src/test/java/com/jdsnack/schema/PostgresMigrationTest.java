package com.jdsnack.schema;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * CI에서 JDSNACK_DB_URL을 주입했을 때 실제 PostgreSQL에 Flyway를 적용한다.
 * 기본 H2 테스트에서는 환경변수가 없으므로 이 테스트가 실행되지 않는다.
 */
@ActiveProfiles("postgres")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE)
@EnabledIfEnvironmentVariable(named = "JDSNACK_DB_URL", matches = "jdbc:postgresql://.+")
class PostgresMigrationTest {

    @Autowired
    private Flyway flyway;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void appliesSchemaAndSeedOnceAndIsIdempotentOnPostgres() {
        assertMigrationHistory();
        assertSeedRows();

        flyway.migrate();

        assertMigrationHistory();
        assertSeedRows();
    }

    private void assertMigrationHistory() {
        List<String> versions = jdbcTemplate.queryForList(
                "SELECT version FROM flyway_schema_history WHERE success = TRUE ORDER BY installed_rank",
                String.class
        );

        assertThat(versions).containsExactly("1", "2", "3");
    }

    private void assertSeedRows() {
        assertThat(count("SELECT COUNT(*) FROM resume_fixture_mapping")).isEqualTo(3);
        assertThat(count("SELECT COUNT(*) FROM fixture_analysis")).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "SELECT summary FROM fixture_analysis WHERE fixture_key = ?",
                String.class,
                "fixture-backend-junior-001"
        )).isEqualTo("백엔드 중심 경험은 분명하지만 성과 수치가 더 필요합니다.");
    }

    private int count(String sql) {
        return jdbcTemplate.queryForObject(sql, Integer.class);
    }
}
