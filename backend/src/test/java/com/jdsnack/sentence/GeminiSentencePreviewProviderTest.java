package com.jdsnack.sentence;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import java.net.http.HttpClient;
import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;

class GeminiSentencePreviewProviderTest {

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final GeminiSentencePreviewProvider provider = new GeminiSentencePreviewProvider(
            objectMapper,
            HttpClient.newHttpClient(),
            "test-key",
            "test-model"
    );

    @Test
    void parsesFencedEditsAndLimitsResultToEight() throws Exception {
        String edits = IntStream.range(0, 10)
                .mapToObj(index -> """
                        {"original":"원문 %d","improved":"개선 %d","reason":"사유 %d"}
                        """.formatted(index, index, index))
                .reduce((left, right) -> left + "," + right)
                .orElseThrow();

        SentencePreviewResponse response = provider.parseResponse(geminiResponse(
                "```json\n{\"edits\":[" + edits + "]}\n```"
        ));

        assertThat(response.edits()).hasSize(8);
        assertThat(response.edits().get(0).improved()).isEqualTo("개선 0");
    }

    @Test
    void missingOrNonArrayEditsBecomeEmptyList() throws Exception {
        assertThat(provider.parseResponse(geminiResponse("{}")).edits()).isEmpty();
        assertThat(provider.parseResponse(geminiResponse("{\"edits\":\"invalid\"}")).edits()).isEmpty();
    }

    @Test
    void promptContainsJsonSchemaAndSafetyRule() {
        String prompt = provider.prompt(validRequest());
        assertThat(prompt).contains("original", "improved", "reason", "at most 8 edits", "do not invent");
    }

    private SentencePreviewRequest validRequest() {
        return new SentencePreviewRequest(
                new SentencePreviewRequest.ResumeSource("TEXT", "이력서 본문 ".repeat(10)),
                "채용 공고 본문 ".repeat(10),
                ""
        );
    }

    private String geminiResponse(String text) throws Exception {
        return """
                {"candidates":[{"content":{"parts":[{"text":%s}]}}]}
                """.formatted(objectMapper.writeValueAsString(text));
    }
}
