package com.jdsnack.diagnose;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.jdsnack.common.ErrorCode;
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
public class GeminiDiagnosisProvider implements DiagnosisProvider {

    private static final String DEFAULT_MODEL = "gemini-2.5-flash";

    private final HttpClient httpClient;
    private final ObjectMapper objectMapper;
    private final String apiKey;
    private final String model;

    @Autowired
    public GeminiDiagnosisProvider(
            ObjectMapper objectMapper,
            @Value("${GEMINI_API_KEY:}") String apiKey,
            @Value("${GEMINI_MODEL:" + DEFAULT_MODEL + "}") String model
    ) {
        this(
                objectMapper,
                HttpClient.newBuilder()
                        .connectTimeout(Duration.ofSeconds(10))
                        .build(),
                apiKey,
                model
        );
    }

    private GeminiDiagnosisProvider(
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
    public DiagnosisResultResponse diagnose(UploadedResumeType inputType, String resumeText) {
        if (apiKey.isBlank()) {
            throw new GeminiApiException(ErrorCode.GEMINI_API_KEY_MISSING);
        }

        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(geminiUri())
                    .timeout(Duration.ofSeconds(30))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody(resumeText)))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new GeminiApiException(ErrorCode.GEMINI_API_REQUEST_FAILED);
            }

            return parseResponse(response.body(), resumeText);
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
        String encodedModel = URLEncoder.encode(model, StandardCharsets.UTF_8);
        String encodedKey = URLEncoder.encode(apiKey, StandardCharsets.UTF_8);
        return URI.create("https://generativelanguage.googleapis.com/v1beta/models/"
                + encodedModel
                + ":generateContent?key="
                + encodedKey);
    }

    private String requestBody(String resumeText) throws IOException {
        return objectMapper.writeValueAsString(new GeminiRequest(List.of(
                new Content(List.of(new Part(prompt(resumeText))))
        )));
    }

    private String prompt(String resumeText) {
        return """
                You are JDSnack, a Korean resume analysis assistant for software engineers.
                Return JSON only. Do not wrap it in markdown.
                Schema:
                {
                  "score": number from 0 to 100,
                  "summary": "short Korean summary",
                  "strengths": ["Korean bullet"],
                  "improvements": ["Korean bullet"]
                }

                Rules:
                - summary must be one or two Korean sentences
                - strengths must contain 2 or 3 items
                - improvements must contain 2 or 3 items
                - keep every bullet concise and practical

                Resume:
                %s
                """.formatted(resumeText);
    }

    private DiagnosisResultResponse parseResponse(String responseBody, String resumeText) throws IOException {
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
        int score = payload.path("score").asInt(-1);
        String summary = payload.path("summary").asText("");
        List<String> strengths = toStringList(payload.path("strengths"));
        List<String> improvements = toStringList(payload.path("improvements"));

        if (score < 0 || score > 100 || summary.isBlank() || strengths.isEmpty() || improvements.isEmpty()) {
            throw new GeminiApiException(ErrorCode.GEMINI_API_RESPONSE_INVALID);
        }

        return new DiagnosisResultResponse(score, summary, strengths, improvements, resumeText);
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

    private List<String> toStringList(JsonNode node) {
        List<String> values = new ArrayList<>();
        if (!node.isArray()) {
            return values;
        }

        node.forEach(value -> {
            String text = value.asText("");
            if (!text.isBlank()) {
                values.add(text);
            }
        });
        return values;
    }

    private record GeminiRequest(List<Content> contents) {
    }

    private record Content(List<Part> parts) {
    }

    private record Part(String text) {
    }
}
