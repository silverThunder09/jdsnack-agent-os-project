package com.jdsnack.match;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.jdsnack.analysis.AnalysisExecutionVersion;
import com.jdsnack.common.ErrorCode;
import com.jdsnack.diagnose.GeminiApiException;
import org.junit.jupiter.api.Test;

import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class GeminiMatchPreviewProviderTest {

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final GeminiMatchPreviewProvider provider =
            new GeminiMatchPreviewProvider(objectMapper, "test-key", "test-model");

    @Test
    void parsesKeywordBreakdownAndRemovesCrossCategoryDuplicates() throws Exception {
        MatchPreviewResponse response = provider.parseResponse(geminiEnvelope("""
                {
                  "matchingScore": 82,
                  "summary": "매칭 요약입니다.",
                  "strengths": ["강점 1"],
                  "gaps": ["보완점 1"],
                  "suggestions": ["제안 1"],
                  "matchedKeywords": ["Spring Boot", "Spring Boot"],
                  "partialKeywords": ["Spring Boot", "CI/CD"],
                  "missingKeywords": ["CI/CD", "Kubernetes"]
                }
                """));

        assertThat(response.matchedKeywords()).containsExactly("Spring Boot");
        assertThat(response.partialKeywords()).containsExactly("CI/CD");
        assertThat(response.missingKeywords()).containsExactly("Kubernetes");
    }

    @Test
    void missingOrNonArrayKeywordFieldsBecomeEmptyLists() throws Exception {
        MatchPreviewResponse response = provider.parseResponse(geminiEnvelope("""
                {
                  "matchingScore": 82,
                  "summary": "매칭 요약입니다.",
                  "strengths": ["강점 1"],
                  "gaps": ["보완점 1"],
                  "suggestions": ["제안 1"],
                  "partialKeywords": "not-an-array"
                }
                """));

        assertThat(response.matchedKeywords()).isEmpty();
        assertThat(response.partialKeywords()).isEmpty();
        assertThat(response.missingKeywords()).isEmpty();
    }

    @Test
    void reportsTheResolvedModelAndMatchPromptVersion() {
        assertThat(provider.executionVersion())
                .isEqualTo(new AnalysisExecutionVersion("test-model", "match-v1"));
        assertThat(provider.connectTimeout()).isEqualTo(Duration.ofSeconds(10));
        assertThat(provider.requestTimeout()).isEqualTo(Duration.ofSeconds(30));
        GeminiMatchPreviewProvider configuredProvider = new GeminiMatchPreviewProvider(objectMapper, "test-key", "test-model", 3, 7);
        assertThat(configuredProvider.connectTimeout()).isEqualTo(Duration.ofSeconds(3));
        assertThat(configuredProvider.requestTimeout()).isEqualTo(Duration.ofSeconds(7));
    }

    @Test
    void mapsInvalidGeminiResponse() throws Exception { assertThatThrownBy(() -> provider.parseResponse(geminiEnvelope(""))).isInstanceOfSatisfying(GeminiApiException.class, exception -> assertThat(exception.errorCode()).isEqualTo(ErrorCode.GEMINI_API_RESPONSE_INVALID)); }
    @Test void mapsTimeoutToRequestFailure() throws Exception { var client = org.mockito.Mockito.mock(java.net.http.HttpClient.class); org.mockito.Mockito.doThrow(new java.net.http.HttpTimeoutException("timeout")).when(client).send(org.mockito.ArgumentMatchers.any(java.net.http.HttpRequest.class), org.mockito.ArgumentMatchers.any(java.net.http.HttpResponse.BodyHandler.class)); assertThatThrownBy(() -> new GeminiMatchPreviewProvider(objectMapper, client, "test-key", "model", Duration.ofSeconds(30)).preview(new MatchPreviewRequest(new MatchPreviewRequest.ResumeSource("TEXT", "resume"), "jd", null))).isInstanceOfSatisfying(GeminiApiException.class, e -> assertThat(e.errorCode()).isEqualTo(ErrorCode.GEMINI_API_REQUEST_FAILED)); }

    private String geminiEnvelope(String payload) throws Exception {
        ArrayNode parts = objectMapper.createArrayNode()
                .add(objectMapper.createObjectNode().put("text", payload));
        ObjectNode content = objectMapper.createObjectNode().set("parts", parts);
        ArrayNode candidates = objectMapper.createArrayNode()
                .add(objectMapper.createObjectNode().set("content", content));
        return objectMapper.writeValueAsString(
                objectMapper.createObjectNode().set("candidates", candidates)
        );
    }
}
