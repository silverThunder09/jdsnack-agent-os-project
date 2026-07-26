package com.jdsnack.analysis;

import com.jdsnack.auth.GoogleAuthService;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpSession;

import java.util.UUID;

final class AnalysisHistoryTestSupport {

    static final String RESUME_TEXT =
            "Experienced backend engineer with Spring Boot REST API development, validation handling, and test automation delivery across projects.";
    static final String JD_TEXT =
            "Spring Boot 기반 REST API 개발과 운영 경험, 테스트 자동화와 배포 경험을 요구합니다. 협업과 장애 대응 경험도 중요합니다.";

    private AnalysisHistoryTestSupport() {
    }

    static String createUser(JdbcTemplate jdbcTemplate) {
        String id = UUID.randomUUID().toString();
        jdbcTemplate.update(
                "INSERT INTO app_user (user_id, provider, provider_subject, email, display_name, created_at, updated_at) "
                        + "VALUES (?, 'google', ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
                id,
                "subject-" + id,
                id + "@example.com",
                "Test User"
        );
        return id;
    }

    static MockHttpSession authenticatedSession(String userId) {
        MockHttpSession session = new MockHttpSession();
        session.setAttribute(GoogleAuthService.SESSION_USER_ID, userId);
        return session;
    }

    static String createRequest() {
        return """
                {
                  "resumeText": "%s",
                  "jd": {
                    "inputType": "TEXT",
                    "text": "%s"
                  }
                }
                """.formatted(RESUME_TEXT, JD_TEXT);
    }
}
