package com.jdsnack.diagnose;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

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

final class GoogleTestDiagnosisProvider implements DiagnosisProvider {

    private static final String DEFAULT_MODEL = "gemini-1.5-flash";

    private final HttpClient httpClient;
    private final ObjectMapper objectMapper;
    private final String apiKey;
    private final String model;

    GoogleTestDiagnosisProvider(ObjectMapper objectMapper, String apiKey, String model) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new IllegalArgumentException("GEMINI_API_KEY is required for googleTest.");
        }

        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
        this.objectMapper = objectMapper;
        this.apiKey = apiKey;
        this.model = model == null || model.isBlank() ? DEFAULT_MODEL : model.trim();
    }

    @Override
    public DiagnosisResultResponse diagnose(UploadedResumeType inputType, String resumeText) {
        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(geminiUri())
                    .timeout(Duration.ofSeconds(30))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody(resumeText)))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new IllegalStateException("Gemini API request failed with status " + response.statusCode());
            }

            return parseResponse(response.body());
        } catch (IOException exception) {
            throw new IllegalStateException("Gemini API response was invalid.", exception);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Gemini API request was interrupted.", exception);
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
                You are testing JDSnack resume diagnosis.
                Return JSON only. Do not wrap it in markdown.
                Schema:
                {
                  "score": number from 0 to 100,
                  "summary": "short Korean summary",
                  "strengths": ["Korean bullet"],
                  "improvements": ["Korean bullet"]
                }

                Resume:
                %s
                """.formatted(resumeText);
    }

    private DiagnosisResultResponse parseResponse(String responseBody) throws IOException {
        JsonNode root = objectMapper.readTree(responseBody);
        String text = root.path("candidates")
                .path(0)
                .path("content")
                .path("parts")
                .path(0)
                .path("text")
                .asText();

        if (text.isBlank()) {
            throw new IllegalStateException("Gemini API response did not include text.");
        }

        JsonNode payload = objectMapper.readTree(stripJsonFence(text));
        int score = payload.path("score").asInt(-1);
        String summary = payload.path("summary").asText("");
        List<String> strengths = toStringList(payload.path("strengths"));
        List<String> improvements = toStringList(payload.path("improvements"));

        if (score < 0 || score > 100 || summary.isBlank() || strengths.isEmpty() || improvements.isEmpty()) {
            throw new IllegalStateException("Gemini API response did not match the expected diagnosis shape.");
        }

        return new DiagnosisResultResponse(score, summary, strengths, improvements);
    }

    private String stripJsonFence(String text) {
        String trimmed = text.trim();
        if (trimmed.startsWith("```json")) {
            return trimmed.substring(7, trimmed.length() - 3).trim();
        }
        if (trimmed.startsWith("```")) {
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
