package com.jdsnack.analysis;

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
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import static com.jdsnack.analysis.AnalysisHistoryTestSupport.JD_TEXT;
import static com.jdsnack.analysis.AnalysisHistoryTestSupport.RESUME_TEXT;
import static com.jdsnack.analysis.AnalysisHistoryTestSupport.authenticatedSession;
import static com.jdsnack.analysis.AnalysisHistoryTestSupport.createRequest;
import static com.jdsnack.analysis.AnalysisHistoryTestSupport.createUser;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = "jdsnack.diagnosis.mode=fixture")
class AnalysisHistoryPartialFailureTest {

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
        userId = createUser(jdbcTemplate);
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

}
