package com.jdsnack.analysis;

import com.jdsnack.diagnose.*;
import com.jdsnack.match.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.*;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.sql.Date;
import java.time.LocalDate;

import static com.jdsnack.analysis.AnalysisHistoryTestSupport.*;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest @AutoConfigureMockMvc
@TestPropertySource(properties = {"jdsnack.diagnosis.mode=fixture", "jdsnack.ai.usage.daily-limit=2"})
class AnalysisHistoryQuotaControllerTest {
    private static final String ENDPOINT = "/api/analysis-histories";
    @Autowired private MockMvc mockMvc;
    @Autowired private JdbcTemplate jdbcTemplate;
    @MockBean private DiagnoseService diagnoseService;
    @MockBean private MatchPreviewService matchPreviewService;
    private String userId;
    @AfterEach void cleanUp() { if (userId != null) jdbcTemplate.update("DELETE FROM app_user WHERE user_id = ?", userId); }

    @Test void rejectsOverQuotaRequestBeforeProvidersOrHistory() throws Exception {
        userId = createUser(jdbcTemplate);
        jdbcTemplate.update("INSERT INTO ai_usage_quota (user_id, usage_date, daily_limit, used_count, endpoint, created_at, updated_at) VALUES (?, ?, 2, 2, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)", userId, Date.valueOf(LocalDate.now(AiUsageQuotaService.SERVICE_ZONE)), ENDPOINT);
        mockMvc.perform(analysisRequest(createRequest())).andExpect(status().isTooManyRequests()).andExpect(jsonPath("$.error.code").value("AI_QUOTA_EXCEEDED")).andExpect(jsonPath("$.error.metadata.retryAfter").isNumber()).andExpect(jsonPath("$.error.metadata.limit").value(2)).andExpect(jsonPath("$.error.metadata.remaining").value(0)).andExpect(jsonPath("$.error.metadata.resetAt").isString());
        assertThat(count("analysis_history")).isZero();
        verifyNoInteractions(diagnoseService, matchPreviewService);
    }

    @Test void validatesResumeLengthBoundariesWithoutConsumingQuota() throws Exception {
        userId = createUser(jdbcTemplate);
        mockMvc.perform(analysisRequest(requestWithResumeLength(49))).andExpect(status().isBadRequest()).andExpect(jsonPath("$.error.code").value("TEXT_TOO_SHORT"));
        mockMvc.perform(analysisRequest(requestWithResumeLength(10_001))).andExpect(status().isBadRequest()).andExpect(jsonPath("$.error.code").value("TEXT_TOO_LONG"));
        assertThat(count("ai_usage_quota")).isZero();
        mockMvc.perform(analysisRequest(requestWithResumeLength(50))).andExpect(status().isOk());
        mockMvc.perform(analysisRequest(requestWithResumeLength(10_000))).andExpect(status().isOk());
        assertThat(jdbcTemplate.queryForObject("SELECT used_count FROM ai_usage_quota WHERE user_id = ?", Integer.class, userId)).isEqualTo(2);
    }

    @Test void rejectsOversizedMultipartWithoutQuota() throws Exception {
        userId = createUser(jdbcTemplate);
        MockMultipartFile file = new MockMultipartFile("resumeFile", "resume.pdf", MediaType.APPLICATION_PDF_VALUE, new byte[10 * 1024 * 1024 + 1]);
        mockMvc.perform(multipart(ENDPOINT + "/file").file(file).param("inputType", "TEXT").param("text", JD_TEXT).session(authenticatedSession(userId))).andExpect(status().isBadRequest()).andExpect(jsonPath("$.error.code").value("FILE_TEXT_EXTRACTION_FAILED"));
        assertThat(count("ai_usage_quota")).isZero(); assertThat(count("ai_usage_ledger")).isZero();
    }

    @Test void rejectsEmptyResumeWithoutQuotaOrLedgerRows() throws Exception {
        userId = createUser(jdbcTemplate);
        mockMvc.perform(analysisRequest(createRequest().replace(RESUME_TEXT, ""))).andExpect(status().isBadRequest()).andExpect(jsonPath("$.error.code").value("EMPTY_RESUME"));
        assertThat(count("ai_usage_quota")).isZero(); assertThat(count("ai_usage_ledger")).isZero();
    }

    private String requestWithResumeLength(int length) { return createRequest().replace(RESUME_TEXT, "a".repeat(length)); }
    private int count(String table) { return jdbcTemplate.queryForObject("SELECT COUNT(*) FROM " + table + " WHERE user_id = ?", Integer.class, userId); }
    private MockHttpServletRequestBuilder analysisRequest(String body) { return post(ENDPOINT).session(authenticatedSession(userId)).contentType(MediaType.APPLICATION_JSON).content(body); }
}
