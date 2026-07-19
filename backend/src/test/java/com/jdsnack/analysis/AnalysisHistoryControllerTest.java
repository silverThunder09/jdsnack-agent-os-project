package com.jdsnack.analysis;

import com.jdsnack.auth.GoogleAuthService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = "jdsnack.diagnosis.mode=fixture")
class AnalysisHistoryControllerTest {

    private static final String RESUME_TEXT =
            "Experienced backend engineer with Spring Boot REST API development, validation handling, and test automation delivery across projects.";
    private static final String JD_TEXT =
            "Spring Boot 기반 REST API 개발과 운영 경험, 테스트 자동화와 배포 경험을 요구합니다. 협업과 장애 대응 경험도 중요합니다.";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private String userId;

    @AfterEach
    void cleanUp() {
        if (userId != null) {
            jdbcTemplate.update("DELETE FROM app_user WHERE user_id = ?", userId);
        }
    }

    @Test
    void authenticatedUserCanCreateAndReadOwnAnalysisHistory() throws Exception {
        userId = createUser();

        String response = mockMvc.perform(post("/api/analysis-histories")
                        .session(authenticatedSession(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createRequest()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.id").isString())
                .andExpect(jsonPath("$.data.status").value("SUCCEEDED"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        String historyId = response.replaceAll(".*\"id\":\"([^\"]+)\".*", "$1");

        mockMvc.perform(get("/api/analysis-histories")
                        .session(authenticatedSession(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].id").value(historyId))
                .andExpect(jsonPath("$.data[0].status").value("SUCCEEDED"));

        mockMvc.perform(get("/api/analysis-histories/{historyId}", historyId)
                        .session(authenticatedSession(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(historyId))
                .andExpect(jsonPath("$.data.input.resumeText").value(RESUME_TEXT))
                .andExpect(jsonPath("$.data.input.jdText").value(JD_TEXT))
                .andExpect(jsonPath("$.data.result.diagnosis").exists())
                .andExpect(jsonPath("$.data.result.match").exists());
    }

    @Test
    void retryCreatesNewHistoryAndDeleteRemovesTheRequestedHistory() throws Exception {
        userId = createUser();

        String createResponse = mockMvc.perform(post("/api/analysis-histories")
                        .session(authenticatedSession(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createRequest()))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String originalId = createResponse.replaceAll(".*\"id\":\"([^\"]+)\".*", "$1");
        String originalSnapshotId = jdbcTemplate.queryForObject(
                "SELECT snapshot_id FROM analysis_history WHERE history_id = ? AND user_id = ?",
                String.class,
                originalId,
                userId
        );

        String retryResponse = mockMvc.perform(post("/api/analysis-histories/{historyId}/retry", originalId)
                        .session(authenticatedSession(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("SUCCEEDED"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String retryId = retryResponse.replaceAll(".*\"id\":\"([^\"]+)\".*", "$1");
        String retrySnapshotId = jdbcTemplate.queryForObject(
                "SELECT snapshot_id FROM analysis_history WHERE history_id = ? AND user_id = ?",
                String.class,
                retryId,
                userId
        );

        org.assertj.core.api.Assertions.assertThat(retryId).isNotEqualTo(originalId);
        org.assertj.core.api.Assertions.assertThat(retrySnapshotId).isNotEqualTo(originalSnapshotId);

        mockMvc.perform(delete("/api/analysis-histories/{historyId}", originalId)
                        .session(authenticatedSession(userId)))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/analysis-histories/{historyId}", originalId)
                        .session(authenticatedSession(userId)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("ANALYSIS_HISTORY_NOT_FOUND"));

        mockMvc.perform(get("/api/analysis-histories/{historyId}", retryId)
                        .session(authenticatedSession(userId)))
                .andExpect(status().isOk());

        org.assertj.core.api.Assertions.assertThat(snapshotCount(originalSnapshotId)).isZero();
        org.assertj.core.api.Assertions.assertThat(snapshotCount(retrySnapshotId)).isEqualTo(1);

        mockMvc.perform(delete("/api/analysis-histories/{historyId}", originalId)
                        .session(authenticatedSession(userId)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("ANALYSIS_HISTORY_NOT_FOUND"));
    }

    @Test
    void anotherUserCannotDiscoverTheHistory() throws Exception {
        userId = createUser();
        String otherUserId = createUser();

        String response = mockMvc.perform(post("/api/analysis-histories")
                        .session(authenticatedSession(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createRequest()))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String historyId = response.replaceAll(".*\"id\":\"([^\"]+)\".*", "$1");

        mockMvc.perform(get("/api/analysis-histories/{historyId}", historyId)
                        .session(authenticatedSession(otherUserId)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("ANALYSIS_HISTORY_NOT_FOUND"));

        jdbcTemplate.update("DELETE FROM app_user WHERE user_id = ?", otherUserId);
    }

    @Test
    void analysisFailureIsStoredAsFailedHistory() throws Exception {
        userId = createUser();

        mockMvc.perform(post("/api/analysis-histories")
                        .session(authenticatedSession(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(failedRequest()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("FAILED"))
                .andExpect(jsonPath("$.data.failure.code").value("FIXTURE_NOT_FOUND"))
                .andExpect(jsonPath("$.data.input.resumeText").value("Platform engineer with distributed tracing rollout, incident command ownership, and multi-region disaster recovery practice across services."));
    }

    private String createUser() {
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

    private MockHttpSession authenticatedSession(String id) {
        MockHttpSession session = new MockHttpSession();
        session.setAttribute(GoogleAuthService.SESSION_USER_ID, id);
        return session;
    }

    private String createRequest() {
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

    private String failedRequest() {
        return """
                {
                  "resumeText": "Platform engineer with distributed tracing rollout, incident command ownership, and multi-region disaster recovery practice across services.",
                  "jd": {
                    "inputType": "TEXT",
                    "text": "%s"
                  }
                }
                """.formatted(JD_TEXT);
    }

    private int snapshotCount(String snapshotId) {
        return jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM analysis_input_snapshot WHERE snapshot_id = ?",
                Integer.class,
                snapshotId
        );
    }
}
