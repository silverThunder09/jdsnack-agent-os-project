package com.jdsnack.interview;

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
import java.util.Set;

@Component
public class GeminiInterviewPreviewProvider implements InterviewPreviewProvider {

    private static final String DEFAULT_MODEL = "gemini-2.5-flash";
    private static final Set<String> CATEGORIES = Set.of("experience", "technical", "behavioral");

    private final HttpClient httpClient;
    private final ObjectMapper objectMapper;
    private final String apiKey;
    private final String model;

    @Autowired
    public GeminiInterviewPreviewProvider(
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

    GeminiInterviewPreviewProvider(
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
    public InterviewPreviewResponse preview(InterviewPreviewRequest request) {
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

    private String requestBody(InterviewPreviewRequest request) throws IOException {
        return objectMapper.writeValueAsString(new GeminiRequest(List.of(
                new Content(List.of(new Part(prompt(request))))
        )));
    }

    private String prompt(InterviewPreviewRequest request) {
        return """
                You are JDSnack, a Korean mock interview coach for software engineers.
                Generate interview questions from the resume and optional job context. Return JSON only. Do not wrap it in markdown.
                Schema:
                {
                  "questions": [
                    {
                      "question": "Korean interview question",
                      "category": "experience | technical | behavioral",
                      "keypoints": "short Korean answer keypoints"
                    }
                  ],
                  "strategy": "short Korean answer strategy",
                  "summary": "short Korean preparation summary"
                }

                Rules:
                - questions must contain 5 to 7 items
                - include at least one question for experience, technical, and behavioral
                - keypoints must be practical and concise
                - if jobTitle or jdText exists, tailor questions to that context

                Resume Source Type:
                %s

                Resume Text:
                %s

                Job Title:
                %s

                JD Text:
                %s
                """.formatted(
                request.resumeSource().type(),
                request.resumeSource().value(),
                emptyToNone(request.jobTitle()),
                emptyToNone(request.jdText())
        );
    }

    InterviewPreviewResponse parseResponse(String responseBody) throws IOException {
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
        List<InterviewPreviewResponse.Question> questions = toQuestions(payload.path("questions"));
        String strategy = payload.path("strategy").asText("");
        String summary = payload.path("summary").asText("");

        if (questions.isEmpty() || strategy.isBlank() || summary.isBlank()) {
            throw new GeminiApiException(ErrorCode.INTERVIEW_QUESTION_GENERATION_FAILED);
        }

        return new InterviewPreviewResponse(questions, strategy, summary);
    }

    private List<InterviewPreviewResponse.Question> toQuestions(JsonNode node) {
        List<InterviewPreviewResponse.Question> values = new ArrayList<>();
        if (!node.isArray()) {
            return values;
        }

        node.forEach(item -> {
            String question = item.path("question").asText("");
            String category = item.path("category").asText("");
            String keypoints = item.path("keypoints").asText("");
            if (!question.isBlank() && CATEGORIES.contains(category) && !keypoints.isBlank()) {
                values.add(new InterviewPreviewResponse.Question(question, category, keypoints));
            }
        });
        return values;
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
