package com.jdsnack.analysis;

import com.jdsnack.common.ErrorCode;
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
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import static com.jdsnack.analysis.AnalysisHistoryTestSupport.JD_TEXT;
import static com.jdsnack.analysis.AnalysisHistoryTestSupport.RESUME_TEXT;
import static com.jdsnack.analysis.AnalysisHistoryTestSupport.authenticatedSession;
import static com.jdsnack.analysis.AnalysisHistoryTestSupport.createRequest;
import static com.jdsnack.analysis.AnalysisHistoryTestSupport.createUser;
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
        userId = createUser(jdbcTemplate);
        given(geminiDiagnosisProvider.diagnose(eq(com.jdsnack.diagnose.UploadedResumeType.TEXT), any()))
                .willReturn(new DiagnosisResultResponse(
                        84,
                        "진단 결과입니다.",
                        List.of("강점"),
                        List.of("개선점"),
                        RESUME_TEXT
                ));
        given(geminiDiagnosisProvider.executionVersion())
                .willReturn(new AnalysisExecutionVersion("configured-diagnosis-model", "diagnosis-v1"));
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
                               match_prompt_version,
                               diagnosis_json
                        FROM analysis_history
                        WHERE history_id = ? AND user_id = ?
                        """,
                (resultSet, rowNum) -> new String[]{
                        resultSet.getString("diagnosis_model_name"),
                        resultSet.getString("diagnosis_prompt_version"),
                        resultSet.getString("match_model_name"),
                        resultSet.getString("match_prompt_version"),
                        resultSet.getString("diagnosis_json")
                },
                historyId,
                userId
        );

        assertThat(metadata[0]).isEqualTo("configured-diagnosis-model");
        assertThat(metadata[1]).isEqualTo("diagnosis-v1");
        assertThat(metadata[2]).isNull();
        assertThat(metadata[3]).isNull();
        assertThat(metadata[4]).isNull();
    }

}
