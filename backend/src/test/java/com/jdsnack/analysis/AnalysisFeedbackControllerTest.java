package com.jdsnack.analysis;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.UUID;

import static com.jdsnack.analysis.AnalysisHistoryTestSupport.JD_TEXT;
import static com.jdsnack.analysis.AnalysisHistoryTestSupport.RESUME_TEXT;
import static com.jdsnack.analysis.AnalysisHistoryTestSupport.authenticatedSession;
import static com.jdsnack.analysis.AnalysisHistoryTestSupport.createRequest;
import static com.jdsnack.analysis.AnalysisHistoryTestSupport.createUser;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = "jdsnack.diagnosis.mode=fixture")
class AnalysisFeedbackControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private String userId;
    private String otherUserId;

    @AfterEach
    void cleanUp() {
        if (userId != null) {
            jdbcTemplate.update("DELETE FROM app_user WHERE user_id = ?", userId);
        }
        if (otherUserId != null) {
            jdbcTemplate.update("DELETE FROM app_user WHERE user_id = ?", otherUserId);
        }
    }

    /** TC-05 (AC-04) 피드백 최초 제출 */
    @Test
    void ownerCanSubmitFeedbackOnSucceededHistory() throws Exception {
        userId = createUser(jdbcTemplate);
        String historyId = createSucceededHistory(userId);

        mockMvc.perform(post("/api/analysis-histories/{historyId}/feedback", historyId)
                        .session(authenticatedSession(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"rating\":\"LIKE\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.historyId").value(historyId))
                .andExpect(jsonPath("$.data.rating").value("LIKE"))
                .andExpect(jsonPath("$.data.comment").isEmpty())
                .andExpect(jsonPath("$.data.updatedAt").isString());

        assertThat(feedbackCount(historyId)).isEqualTo(1);
    }

    /** TC-06 (AC-04) 피드백 갱신(upsert) */
    @Test
    void resubmittingFeedbackUpdatesTheExistingRecord() throws Exception {
        userId = createUser(jdbcTemplate);
        String historyId = createSucceededHistory(userId);

        submitFeedback(historyId, "{\"rating\":\"LIKE\"}");

        mockMvc.perform(post("/api/analysis-histories/{historyId}/feedback", historyId)
                        .session(authenticatedSession(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"rating\":\"DISLIKE\",\"comment\":\"개선 필요\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.rating").value("DISLIKE"))
                .andExpect(jsonPath("$.data.comment").value("개선 필요"));

        assertThat(feedbackCount(historyId)).isEqualTo(1);
    }

    /** TC-07 (AC-04) 코멘트 길이 검증 */
    @Test
    void commentLongerThanFiveHundredCharactersIsRejected() throws Exception {
        userId = createUser(jdbcTemplate);
        String historyId = createSucceededHistory(userId);

        String tooLong = "가".repeat(501);

        mockMvc.perform(post("/api/analysis-histories/{historyId}/feedback", historyId)
                        .session(authenticatedSession(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"rating\":\"LIKE\",\"comment\":\"" + tooLong + "\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("INVALID_FEEDBACK_INPUT"));

        assertThat(feedbackCount(historyId)).isZero();
    }

    /** TC-07 경계 — 정확히 500자는 허용된다 */
    @Test
    void commentOfExactlyFiveHundredCharactersIsAccepted() throws Exception {
        userId = createUser(jdbcTemplate);
        String historyId = createSucceededHistory(userId);

        String boundary = "가".repeat(500);

        mockMvc.perform(post("/api/analysis-histories/{historyId}/feedback", historyId)
                        .session(authenticatedSession(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"rating\":\"LIKE\",\"comment\":\"" + boundary + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.comment").value(boundary));
    }

    /** TC-07 관련 — rating 누락·잘못된 값도 400 */
    @Test
    void missingOrUnknownRatingIsRejected() throws Exception {
        userId = createUser(jdbcTemplate);
        String historyId = createSucceededHistory(userId);

        mockMvc.perform(post("/api/analysis-histories/{historyId}/feedback", historyId)
                        .session(authenticatedSession(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"comment\":\"rating 없음\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("INVALID_FEEDBACK_INPUT"));

        mockMvc.perform(post("/api/analysis-histories/{historyId}/feedback", historyId)
                        .session(authenticatedSession(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"rating\":\"MAYBE\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("INVALID_FEEDBACK_INPUT"));
    }

    /** TC-08 (AC-05) 상세 조회에 피드백 포함, 없으면 null */
    @Test
    void historyDetailIncludesFeedbackAndNullWhenAbsent() throws Exception {
        userId = createUser(jdbcTemplate);
        String withFeedback = createSucceededHistory(userId);
        String withoutFeedback = createSucceededHistory(userId);

        submitFeedback(withFeedback, "{\"rating\":\"LIKE\",\"comment\":\"핵심 개선점이 명확했어요.\"}");

        mockMvc.perform(get("/api/analysis-histories/{historyId}", withFeedback)
                        .session(authenticatedSession(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.feedback.rating").value("LIKE"))
                .andExpect(jsonPath("$.data.feedback.comment").value("핵심 개선점이 명확했어요."))
                .andExpect(jsonPath("$.data.feedback.updatedAt").isString());

        mockMvc.perform(get("/api/analysis-histories/{historyId}", withoutFeedback)
                        .session(authenticatedSession(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.feedback").isEmpty());
    }

    /** TC-09 (AC-06) 소유권 경계 */
    @Test
    void otherUserCannotSubmitOrReadFeedback() throws Exception {
        userId = createUser(jdbcTemplate);
        otherUserId = createUser(jdbcTemplate);
        String historyId = createSucceededHistory(userId);

        mockMvc.perform(post("/api/analysis-histories/{historyId}/feedback", historyId)
                        .session(authenticatedSession(otherUserId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"rating\":\"LIKE\"}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("ANALYSIS_HISTORY_NOT_FOUND"));

        mockMvc.perform(get("/api/analysis-histories/{historyId}", historyId)
                        .session(authenticatedSession(otherUserId)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("ANALYSIS_HISTORY_NOT_FOUND"));

        assertThat(feedbackCount(historyId)).isZero();
    }

    /** TC-10 (AC-06) 상태 경계 */
    @Test
    void feedbackOnRunningOrFailedHistoryIsRejected() throws Exception {
        userId = createUser(jdbcTemplate);
        String runningId = insertHistoryWithStatus(userId, AnalysisHistoryStatus.RUNNING);
        String failedId = insertHistoryWithStatus(userId, AnalysisHistoryStatus.FAILED);

        for (String historyId : new String[]{runningId, failedId}) {
            mockMvc.perform(post("/api/analysis-histories/{historyId}/feedback", historyId)
                            .session(authenticatedSession(userId))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"rating\":\"LIKE\"}"))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.error.code").value("ANALYSIS_NOT_COMPLETED"));

            assertThat(feedbackCount(historyId)).isZero();
        }
    }

    /** TC-11 (AC-07) 삭제 시 피드백 연쇄 삭제 */
    @Test
    void deletingHistoryAlsoDeletesFeedback() throws Exception {
        userId = createUser(jdbcTemplate);
        String historyId = createSucceededHistory(userId);

        submitFeedback(historyId, "{\"rating\":\"LIKE\",\"comment\":\"좋았어요\"}");
        assertThat(feedbackCount(historyId)).isEqualTo(1);

        mockMvc.perform(delete("/api/analysis-histories/{historyId}", historyId)
                        .session(authenticatedSession(userId)))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/analysis-histories/{historyId}", historyId)
                        .session(authenticatedSession(userId)))
                .andExpect(status().isNotFound());

        assertThat(feedbackCount(historyId)).isZero();
    }

    /** TC-12 (AC-07) 재시도 시 피드백 미상속 */
    @Test
    void retriedHistoryDoesNotInheritFeedback() throws Exception {
        userId = createUser(jdbcTemplate);
        String originalId = createSucceededHistory(userId);

        submitFeedback(originalId, "{\"rating\":\"LIKE\",\"comment\":\"원본 피드백\"}");

        String retryResponse = mockMvc.perform(post("/api/analysis-histories/{historyId}/retry", originalId)
                        .session(authenticatedSession(userId)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String retryId = JsonPath.read(retryResponse, "$.data.id");

        mockMvc.perform(get("/api/analysis-histories/{historyId}", retryId)
                        .session(authenticatedSession(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.feedback").isEmpty());

        mockMvc.perform(get("/api/analysis-histories/{historyId}", originalId)
                        .session(authenticatedSession(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.feedback.rating").value("LIKE"))
                .andExpect(jsonPath("$.data.feedback.comment").value("원본 피드백"));
    }

    private void submitFeedback(String historyId, String body) throws Exception {
        mockMvc.perform(post("/api/analysis-histories/{historyId}/feedback", historyId)
                        .session(authenticatedSession(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk());
    }

    private String createSucceededHistory(String owner) throws Exception {
        String response = mockMvc.perform(post("/api/analysis-histories")
                        .session(authenticatedSession(owner))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createRequest()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("SUCCEEDED"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        return JsonPath.read(response, "$.data.id");
    }

    private String insertHistoryWithStatus(String owner, AnalysisHistoryStatus status) {
        String snapshotId = UUID.randomUUID().toString();
        jdbcTemplate.update(
                "INSERT INTO analysis_input_snapshot ("
                        + "snapshot_id, user_id, resume_text, jd_input_type, jd_text, created_at) "
                        + "VALUES (?, ?, ?, 'TEXT', ?, CURRENT_TIMESTAMP)",
                snapshotId,
                owner,
                RESUME_TEXT,
                JD_TEXT
        );

        String historyId = UUID.randomUUID().toString();
        jdbcTemplate.update(
                "INSERT INTO analysis_history ("
                        + "history_id, user_id, snapshot_id, status, created_at, updated_at) "
                        + "VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
                historyId,
                owner,
                snapshotId,
                status.name()
        );
        return historyId;
    }

    private Integer feedbackCount(String historyId) {
        return jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM analysis_feedback WHERE history_id = ?",
                Integer.class,
                historyId
        );
    }
}
