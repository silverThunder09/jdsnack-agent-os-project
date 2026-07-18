package com.jdsnack.analysis;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
class AnalysisInputSnapshotRepositoryTest {

    @Autowired
    private AnalysisInputSnapshotRepository repository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void savesSnapshotAndAppliesUserOwnershipFilter() {
        String userId = UUID.randomUUID().toString();
        String otherUserId = UUID.randomUUID().toString();
        createUser(userId);
        createUser(otherUserId);

        try {
            AnalysisInputSnapshot snapshot = new AnalysisInputSnapshot(
                    UUID.randomUUID().toString(),
                    userId,
                    "정규화된 이력서 텍스트입니다. Spring Boot API 운영 경험이 있습니다.",
                    JdInputType.SARAMIN_URL,
                    "정규화된 JD 본문입니다. 백엔드 개발과 테스트 자동화 경험을 요구합니다.",
                    "https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=123",
                    "saramin",
                    "static-html",
                    Instant.parse("2026-07-19T00:00:00Z")
            );

            AnalysisInputSnapshot saved = repository.save(snapshot);

            assertThat(saved).isEqualTo(snapshot);
            assertThat(repository.findByIdAndUserId(snapshot.id(), userId)).contains(snapshot);
            assertThat(repository.findByIdAndUserId(snapshot.id(), otherUserId)).isEmpty();
        } finally {
            jdbcTemplate.update("DELETE FROM app_user WHERE user_id IN (?, ?)", userId, otherUserId);
        }
    }

    private void createUser(String userId) {
        jdbcTemplate.update(
                "INSERT INTO app_user (user_id, provider, provider_subject, email, display_name, created_at, updated_at) "
                        + "VALUES (?, 'google', ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
                userId,
                "subject-" + userId,
                userId + "@example.com",
                "Test User"
        );
    }
}
