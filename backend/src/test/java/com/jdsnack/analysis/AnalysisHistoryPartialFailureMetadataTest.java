package com.jdsnack.analysis;

import com.jdsnack.auth.GoogleAuthService;
import com.jdsnack.common.ErrorCode;
import com.jdsnack.common.ProviderMetadata;
import com.jdsnack.diagnose.DiagnosisResultResponse;
import com.jdsnack.diagnose.GeminiApiException;
import com.jdsnack.diagnose.GeminiDiagnosisProvider;
import com.jdsnack.match.GeminiMatchPreviewProvider;
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

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = "jdsnack.diagnosis.mode=ai-local")
class AnalysisHistoryPartialFailureMetadataTest {

    private static final String RESUME_TEXT =
            "Experienced backend engineer with Spring Boot REST API development, validation handling, and test automation delivery across projects.";
    private static final String JD_TEXT =
            "Spring Boot 기반 REST API 개발과 운영 경험, 테스트 자동화와 배포 경험을 요구합니다. 협업과 장애 대응 경험도 중요합니다.";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @MockBean
    private GeminiDiagnosisProvider geminiDiagnosisProvider;

    @MockBean
    private GeminiMatchPreviewProvider geminiMatchPreviewProvider;

    private String userId;

    @AfterEach
    void cleanUp() {
        if (userId != null) {
            jdbcTemplate.update("DELETE FROM app_user WHERE user_id = ?", userId);
        }
    }

    @Test
    void retainsOnlyCompletedDiagnosisMetadataWhenMatchFails() throws Exception {
        userId = createUser();
        given(geminiDiagnosisProvider.diagnose(eq(com.jdsnack.diagnose.UploadedResumeType.TEXT), any()))
                .willReturn(new DiagnosisResultResponse(
                        84,
                        "진단 결과입니다.",
                        List.of("강점"),
                        List.of("개선점"),
                        RESUME_TEXT
                ));
        given(geminiDiagnosisProvider.providerMetadata())
                .willReturn(new ProviderMetadata("configured-diagnosis-model", "diagnosis-v1"));
        given(geminiMatchPreviewProvider.preview(any()))
                .willThrow(new GeminiApiException(ErrorCode.GEMINI_API_REQUEST_FAILED));

        String response = mockMvc.perform(post("/api/analysis-histories")
                        .session(authenticatedSession(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createRequest()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("FAILED"))
                .andExpect(jsonPath("$.data.failure.code").value("GEMINI_API_REQUEST_FAILED"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String historyId = response.replaceAll(".*\\\"id\\\":\\\"([^\\\"]+)\\\".*", "$1");

        String[] metadata = jdbcTemplate.queryForObject(
                """
                        SELECT diagnosis_model_name,
                               diagnosis_prompt_version,
                               match_model_name,
                               match_prompt_version
                        FROM analysis_history
                        WHERE history_id = ? AND user_id = ?
                        """,
                (resultSet, rowNum) -> new String[]{
                        resultSet.getString("diagnosis_model_name"),
                        resultSet.getString("diagnosis_prompt_version"),
                        resultSet.getString("match_model_name"),
                        resultSet.getString("match_prompt_version")
                },
                historyId,
                userId
        );

        assertThat(metadata[0]).isEqualTo("configured-diagnosis-model");
        assertThat(metadata[1]).isEqualTo("diagnosis-v1");
        assertThat(metadata[2]).isNull();
        assertThat(metadata[3]).isNull();
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
