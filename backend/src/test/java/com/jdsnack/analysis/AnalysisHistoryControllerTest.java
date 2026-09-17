package com.jdsnack.analysis;

import org.apache.pdfbox.pdmodel.*;
import org.apache.pdfbox.pdmodel.font.*;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.ResultActions;

import java.io.ByteArrayOutputStream;
import java.io.IOException;

import static org.assertj.core.api.Assertions.assertThat;
import static com.jdsnack.analysis.AnalysisHistoryTestSupport.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = "jdsnack.diagnosis.mode=fixture")
class AnalysisHistoryControllerTest {

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
        userId = createUser(jdbcTemplate);

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
    void sameUserIdempotencyKeyReturnsTheSameHistoryWithoutCreatingAnotherQuotaEntry() throws Exception {
        userId = createUser(jdbcTemplate);
        String firstHistoryId = historyId(mockMvc.perform(analysisRequest(userId, "same-user-key")));
        String retryHistoryId = historyId(mockMvc.perform(analysisRequest(userId, "same-user-key")).andExpect(jsonPath("$.data.id").value(firstHistoryId)).andExpect(jsonPath("$.data.status").value("SUCCEEDED")));
        assertThat(retryHistoryId).isEqualTo(firstHistoryId);
        assertThat(count("analysis_history", "user_id = ? AND idempotency_key = ?", userId, "same-user-key")).isEqualTo(1);
        assertThat(count("ai_usage_ledger")).isEqualTo(1);
    }

    @Test
    void sameIdempotencyKeyIsIndependentAcrossUsers() throws Exception {
        userId = createUser(jdbcTemplate);
        String otherUserId = createUser(jdbcTemplate);
        try {
            String firstHistoryId = historyId(mockMvc.perform(analysisRequest(userId, "shared-key")));
            String otherHistoryId = historyId(mockMvc.perform(analysisRequest(otherUserId, "shared-key")).andExpect(jsonPath("$.data.status").value("SUCCEEDED")));
            assertThat(otherHistoryId).isNotEqualTo(firstHistoryId);
            assertThat(count("ai_usage_ledger", "user_id = ?", otherUserId)).isEqualTo(1);
        } finally {
            jdbcTemplate.update("DELETE FROM app_user WHERE user_id = ?", otherUserId);
        }
    }

    @Test
    void storesExecutionVersionsInternallyWithoutExposingThem() throws Exception {
        userId = createUser(jdbcTemplate);

        String response = mockMvc.perform(post("/api/analysis-histories")
                        .session(authenticatedSession(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createRequest()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.diagnosisModelName").doesNotExist())
                .andExpect(jsonPath("$.data.diagnosisPromptVersion").doesNotExist())
                .andExpect(jsonPath("$.data.matchModelName").doesNotExist())
                .andExpect(jsonPath("$.data.matchPromptVersion").doesNotExist())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String historyId = response.replaceAll(".*\"id\":\"([^\"]+)\".*", "$1");

        assertStoredExecutionVersions(historyId);

        mockMvc.perform(get("/api/analysis-histories")
                        .session(authenticatedSession(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].diagnosisModelName").doesNotExist())
                .andExpect(jsonPath("$.data[0].diagnosisPromptVersion").doesNotExist())
                .andExpect(jsonPath("$.data[0].matchModelName").doesNotExist())
                .andExpect(jsonPath("$.data[0].matchPromptVersion").doesNotExist());

        mockMvc.perform(get("/api/analysis-histories/{historyId}", historyId)
                        .session(authenticatedSession(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.diagnosisModelName").doesNotExist())
                .andExpect(jsonPath("$.data.diagnosisPromptVersion").doesNotExist())
                .andExpect(jsonPath("$.data.matchModelName").doesNotExist())
                .andExpect(jsonPath("$.data.matchPromptVersion").doesNotExist());

        String retryResponse = mockMvc.perform(post("/api/analysis-histories/{historyId}/retry", historyId)
                        .session(authenticatedSession(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.diagnosisModelName").doesNotExist())
                .andExpect(jsonPath("$.data.diagnosisPromptVersion").doesNotExist())
                .andExpect(jsonPath("$.data.matchModelName").doesNotExist())
                .andExpect(jsonPath("$.data.matchPromptVersion").doesNotExist())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String retryId = retryResponse.replaceAll(".*\"id\":\"([^\"]+)\".*", "$1");

        assertStoredExecutionVersions(retryId);
    }

    @Test
    void fileHistoryCreationDoesNotExposeExecutionVersions() throws Exception {
        userId = createUser(jdbcTemplate);
        MockMultipartFile resumeFile = new MockMultipartFile(
                "resumeFile",
                "resume.pdf",
                MediaType.APPLICATION_PDF_VALUE,
                createPdfBytes(RESUME_TEXT)
        );

        String response = mockMvc.perform(multipart("/api/analysis-histories/file")
                        .file(resumeFile)
                        .param("inputType", "TEXT")
                        .param("text", JD_TEXT)
                        .session(authenticatedSession(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.diagnosisModelName").doesNotExist())
                .andExpect(jsonPath("$.data.diagnosisPromptVersion").doesNotExist())
                .andExpect(jsonPath("$.data.matchModelName").doesNotExist())
                .andExpect(jsonPath("$.data.matchPromptVersion").doesNotExist())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String historyId = response.replaceAll(".*\"id\":\"([^\"]+)\".*", "$1");

        assertStoredExecutionVersions(historyId);
    }

    @Test
    void retryCreatesNewHistoryAndDeleteRemovesTheRequestedHistory() throws Exception {
        userId = createUser(jdbcTemplate);

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
        userId = createUser(jdbcTemplate);
        String otherUserId = createUser(jdbcTemplate);

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
        userId = createUser(jdbcTemplate);

        mockMvc.perform(post("/api/analysis-histories")
                        .session(authenticatedSession(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(failedRequest()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("FAILED"))
                .andExpect(jsonPath("$.data.failure.code").value("FIXTURE_NOT_FOUND"))
                .andExpect(jsonPath("$.data.input.resumeText").value("Platform engineer with distributed tracing rollout, incident command ownership, and multi-region disaster recovery practice across services."));
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

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder analysisRequest(String userId, String idempotencyKey) { return post("/api/analysis-histories").session(authenticatedSession(userId)).header("Idempotency-Key", idempotencyKey).contentType(MediaType.APPLICATION_JSON).content(createRequest()); }

    private String historyId(ResultActions actions) throws Exception { return historyId(actions.andExpect(status().isOk()).andReturn()); }
    private String historyId(MvcResult result) throws Exception { return result.getResponse().getContentAsString().replaceAll(".*\"id\":\"([^\"]+)\".*", "$1"); }

    private int count(String table) { return count(table, "user_id = ?", userId); }

    private int count(String table, String where, Object... args) { return jdbcTemplate.queryForObject("SELECT COUNT(*) FROM " + table + " WHERE " + where, Integer.class, args); }

    private void assertStoredExecutionVersions(String historyId) {
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
        org.assertj.core.api.Assertions.assertThat(matchModelName).isNotBlank();
        org.assertj.core.api.Assertions.assertThat(matchPromptVersion).isNotBlank();
    }

    private byte[] createPdfBytes(String text) throws IOException {
        try (PDDocument document = new PDDocument();
             ByteArrayOutputStream outputStream = new ByteArrayOutputStream()) {
            document.addPage(new PDPage());
            try (PDPageContentStream contentStream = new PDPageContentStream(document, document.getPage(0))) {
                contentStream.beginText();
                contentStream.setFont(new PDType1Font(Standard14Fonts.FontName.HELVETICA), 12);
                contentStream.newLineAtOffset(50, 700);
                contentStream.showText(text);
                contentStream.endText();
            }
            document.save(outputStream);
            return outputStream.toByteArray();
        }
    }
}
