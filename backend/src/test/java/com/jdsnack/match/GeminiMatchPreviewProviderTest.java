package com.jdsnack.match;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

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
