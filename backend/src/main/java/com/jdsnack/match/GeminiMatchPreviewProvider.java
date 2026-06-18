package com.jdsnack.match;

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
public class GeminiMatchPreviewProvider {

    private static final String DEFAULT_MODEL = "gemini-2.5-flash";
    private static final int MAX_KEYWORDS = 8;

    private final HttpClient httpClient;
    private final ObjectMapper objectMapper;
    private final String apiKey;
    private final String model;

    @Autowired
    public GeminiMatchPreviewProvider(
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

    private GeminiMatchPreviewProvider(
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

    public MatchPreviewResponse preview(MatchPreviewRequest request) {
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
        String encodedModel = URLEncoder.encode(model, StandardCharsets.UTF_8);
        String encodedKey = URLEncoder.encode(apiKey, StandardCharsets.UTF_8);
        return URI.create("https://generativelanguage.googleapis.com/v1beta/models/"
                + encodedModel
                + ":generateContent?key="
                + encodedKey);
    }

    private String requestBody(MatchPreviewRequest request) throws IOException {
        return objectMapper.writeValueAsString(new GeminiRequest(List.of(
                new Content(List.of(new Part(prompt(request))))
        )));
    }

    private String prompt(MatchPreviewRequest request) {
        return """
                You are JDSnack, a Korean job-description matching assistant for software engineers.
                Compare the resume text and JD text, then return JSON only. Do not wrap it in markdown.
                Schema:
                {
                  "matchingScore": number from 0 to 100,
                  "summary": "short Korean summary",
                  "strengths": ["Korean bullet"],
                  "gaps": ["Korean bullet"],
                  "suggestions": ["Korean bullet"],
                  "matchedKeywords": ["JD keyword found directly in resume"],
                  "partialKeywords": ["JD keyword found by synonym or spelling variation"],
                  "missingKeywords": ["JD keyword not found in resume"]
                }

                Rules:
                - summary must be one or two Korean sentences
                - strengths, gaps, suggestions must contain 2 or 3 items each
                - keep every bullet concise and practical
                - focus on concrete resume evidence, missing keywords, and next resume improvements
                - keyword arrays must be mutually exclusive and contain at most 8 concise items each
                - if jdUrl exists, treat it as source metadata only

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
                request.jdUrl() == null || request.jdUrl().isBlank() ? "(none)" : request.jdUrl()
        );
    }

    MatchPreviewResponse parseResponse(String responseBody) throws IOException {
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
        int matchingScore = payload.path("matchingScore").asInt(-1);
        String summary = payload.path("summary").asText("");
        List<String> strengths = toStringList(payload.path("strengths"));
        List<String> gaps = toStringList(payload.path("gaps"));
        List<String> suggestions = toStringList(payload.path("suggestions"));
        List<String> matchedKeywords = keywordList(payload.path("matchedKeywords"), List.of());
        List<String> partialKeywords = keywordList(payload.path("partialKeywords"), matchedKeywords);
        List<String> excludedKeywords = new ArrayList<>(matchedKeywords);
        excludedKeywords.addAll(partialKeywords);
        List<String> missingKeywords = keywordList(payload.path("missingKeywords"), excludedKeywords);

        if (matchingScore < 0 || matchingScore > 100
                || summary.isBlank()
                || strengths.isEmpty()
                || gaps.isEmpty()
                || suggestions.isEmpty()) {
            throw new GeminiApiException(ErrorCode.GEMINI_API_RESPONSE_INVALID);
        }

        return new MatchPreviewResponse(
                matchingScore,
                summary,
                strengths,
                gaps,
                suggestions,
                matchedKeywords,
                partialKeywords,
                missingKeywords
        );
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

    private List<String> keywordList(JsonNode node, List<String> excluded) {
        return toStringList(node).stream()
                .map(String::trim)
                .filter(keyword -> !excluded.contains(keyword))
                .distinct()
                .limit(MAX_KEYWORDS)
                .toList();
    }

    private record GeminiRequest(List<Content> contents) {
    }

    private record Content(List<Part> parts) {
    }

    private record Part(String text) {
    }
}
