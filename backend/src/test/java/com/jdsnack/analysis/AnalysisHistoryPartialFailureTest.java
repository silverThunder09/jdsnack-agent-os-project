package com.jdsnack.analysis;

import com.jdsnack.auth.GoogleAuthService;
import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import com.jdsnack.match.MatchPreviewService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = "jdsnack.diagnosis.mode=fixture")
class AnalysisHistoryPartialFailureTest {

    private static final String RESUME_TEXT =
            "Experienced backend engineer with Spring Boot REST API development, validation handling, and test automation delivery across projects.";
    private static final String JD_TEXT =
            "Spring Boot 기반 REST API 개발과 운영 경험, 테스트 자동화와 배포 경험을 요구합니다. 협업과 장애 대응 경험도 중요합니다.";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @MockBean
    private MatchPreviewService matchPreviewService;

    private String userId;

    @AfterEach
    void cleanUp() {
        if (userId != null) {
            jdbcTemplate.update("DELETE FROM app_user WHERE user_id = ?", userId);
        }
    }

    @Test
    void preservesDiagnosisExecutionVersionWhenMatchFails() throws Exception {
        userId = createUser();
        given(matchPreviewService.preview(any()))
                .willThrow(new ApiException(ErrorCode.GEMINI_API_REQUEST_FAILED));

        String response = mockMvc.perform(post("/api/analysis-histories")
                        .session(authenticatedSession(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createRequest()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("FAILED"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String historyId = response.replaceAll(".*\"id\":\"([^\"]+)\".*", "$1");

        String diagnosisModelName = jdbcTemplate.queryForObject(
                "SELECT diagnosis_model_name FROM analysis_history WHERE history_id = ? AND user_id = ?",
                String.class,
                historyId,
                userId
        );
        String diagnosisPromptVersion = jdbcTemplate.queryForObject(
                "SELECT diagnosis_prompt_version FROM analysis_history WHERE history_id = ? AND user_id = ?",
                String.class,
                historyId,
                userId
        );
        String diagnosisJson = jdbcTemplate.queryForObject(
                "SELECT diagnosis_json FROM analysis_history WHERE history_id = ? AND user_id = ?",
                String.class,
                historyId,
                userId
        );
        String matchModelName = jdbcTemplate.queryForObject(
                "SELECT match_model_name FROM analysis_history WHERE history_id = ? AND user_id = ?",
                String.class,
                historyId,
                userId
        );
        String matchPromptVersion = jdbcTemplate.queryForObject(
                "SELECT match_prompt_version FROM analysis_history WHERE history_id = ? AND user_id = ?",
                String.class,
                historyId,
                userId
        );

        org.assertj.core.api.Assertions.assertThat(diagnosisModelName).isNotBlank();
        org.assertj.core.api.Assertions.assertThat(diagnosisPromptVersion).isNotBlank();
        org.assertj.core.api.Assertions.assertThat(diagnosisJson).isNull();
        org.assertj.core.api.Assertions.assertThat(matchModelName).isNull();
        org.assertj.core.api.Assertions.assertThat(matchPromptVersion).isNull();
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
}
