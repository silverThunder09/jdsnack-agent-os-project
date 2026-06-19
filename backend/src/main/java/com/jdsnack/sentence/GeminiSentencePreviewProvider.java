package com.jdsnack.sentence;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.jdsnack.common.ErrorCode;
import com.jdsnack.diagnose.GeminiApiException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;

@Component
public class GeminiSentencePreviewProvider implements SentencePreviewProvider {

    private static final String DEFAULT_MODEL = "gemini-2.5-flash";

    private final HttpClient httpClient;
    private final ObjectMapper objectMapper;
    private final String apiKey;
    private final String model;

    @Autowired
    public GeminiSentencePreviewProvider(
            ObjectMapper objectMapper,
            @Value("${GEMINI_API_KEY:}") String apiKey,
            @Value("${GEMINI_MODEL:" + DEFAULT_MODEL + "}") String model
    ) {
        this(
                objectMapper,
                HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build(),
                apiKey,
                model
        );
    }

    GeminiSentencePreviewProvider(
            ObjectMapper objectMapper,
            HttpClient httpClient,
            String apiKey,
            String model
    ) {
        this.objectMapper = objectMapper;
        this.httpClient = httpClient;
        this.apiKey = apiKey == null ? "" : apiKey.trim();
        this.model = model == null || model.isBlank() ? DEFAULT_MODEL : model.trim();
    }

    @Override
    public SentencePreviewResponse preview(SentencePreviewRequest request) {
        if (apiKey.isBlank()) {
            throw new GeminiApiException(ErrorCode.GEMINI_API_KEY_MISSING);
        }

        try {
            HttpRequest httpRequest = HttpRequest.newBuilder()
                    .uri(geminiUri())
                    .timeout(Duration.ofSeconds(30))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody(request)))
                    .build();
            HttpResponse<String> response = httpClient.send(httpRequest, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new GeminiApiException(ErrorCode.GEMINI_API_REQUEST_FAILED);
            }
            return parseResponse(response.body());
        } catch (GeminiApiException exception) {
            throw exception;
        } catch (IOException exception) {
            throw new GeminiApiException(ErrorCode.GEMINI_API_RESPONSE_INVALID, exception);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new GeminiApiException(ErrorCode.GEMINI_API_REQUEST_FAILED, exception);
        }
    }

    private URI geminiUri() {
        return URI.create("https://generativelanguage.googleapis.com/v1beta/models/"
                + URLEncoder.encode(model, StandardCharsets.UTF_8)
                + ":generateContent?key="
                + URLEncoder.encode(apiKey, StandardCharsets.UTF_8));
    }

    private String requestBody(SentencePreviewRequest request) throws IOException {
        return objectMapper.writeValueAsString(new GeminiRequest(List.of(
                new Content(List.of(new Part(prompt(request))))
        )));
    }

    String prompt(SentencePreviewRequest request) {
        return """
                You are JDSnack, a Korean resume sentence editor for software engineers.
                Improve resume sentences to align with the JD. Return JSON only without markdown.
                Schema:
                {
                  "edits": [
                    {
                      "original": "original resume sentence",
                      "improved": "improved Korean sentence aligned to the JD",
                      "reason": "short Korean improvement reason"
                    }
                  ]
                }

                Rules:
                - return at most 8 edits
                - every edit must include original, improved, and reason
                - keep the original facts; do not invent experience or metrics
                - make reasons concise and practical in Korean
                - return JSON only

                Resume Source Type:
                %s

                Resume Text:
                %s

                JD Text:
                %s

                JD URL:
                %s
                """.formatted(
                request.resumeSource().type(),
                request.resumeSource().value(),
                request.jdText(),
                emptyToNone(request.jdUrl())
        );
    }

    SentencePreviewResponse parseResponse(String responseBody) throws IOException {
        JsonNode root = objectMapper.readTree(responseBody);
        String text = root.path("candidates")
                .path(0)
                .path("content")
                .path("parts")
                .path(0)
                .path("text")
                .asText();
        if (text.isBlank()) {
            throw new GeminiApiException(ErrorCode.GEMINI_API_RESPONSE_INVALID);
        }

        JsonNode payload = objectMapper.readTree(stripJsonFence(text));
        return new SentencePreviewResponse(toEdits(payload.path("edits")));
    }

    private List<SentenceEdit> toEdits(JsonNode node) {
        List<SentenceEdit> edits = new ArrayList<>();
        if (!node.isArray()) {
            return edits;
        }
        node.forEach(item -> edits.add(new SentenceEdit(
                item.path("original").asText(""),
                item.path("improved").asText(""),
                item.path("reason").asText("")
        )));
        return edits;
    }

    private String stripJsonFence(String text) {
        String trimmed = text.trim();
        if (trimmed.startsWith("```json") && trimmed.endsWith("```")) {
            return trimmed.substring(7, trimmed.length() - 3).trim();
        }
        if (trimmed.startsWith("```") && trimmed.endsWith("```")) {
            return trimmed.substring(3, trimmed.length() - 3).trim();
        }
        return trimmed;
    }

    private String emptyToNone(String value) {
        return value == null || value.isBlank() ? "(none)" : value;
    }

    private record GeminiRequest(List<Content> contents) {
    }

    private record Content(List<Part> parts) {
    }

    private record Part(String text) {
    }
}
