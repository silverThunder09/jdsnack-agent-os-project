package com.jdsnack.jd;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
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
import java.util.Base64;
import java.util.List;

@Component
public class GeminiJdImageOcr implements JdImageOcr {

    private static final String DEFAULT_MODEL = "gemini-2.5-flash";
    private static final String OCR_PROMPT = """
            Extract only the text visibly present in this job-description image.
            Preserve the original language and reading order.
            Do not translate, summarize, explain, or wrap the result in markdown.
            Return plain text only.
            """;

    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;
    private final String apiKey;
    private final String model;

    @Autowired
    public GeminiJdImageOcr(
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

    GeminiJdImageOcr(ObjectMapper objectMapper, HttpClient httpClient, String apiKey, String model) {
        this.objectMapper = objectMapper;
        this.httpClient = httpClient;
        this.apiKey = apiKey == null ? "" : apiKey.trim();
        this.model = model == null || model.isBlank() ? DEFAULT_MODEL : model.trim();
    }

    @Override
    public boolean isAvailable() {
        return !apiKey.isBlank();
    }

    @Override
    public String extractText(byte[] imageBytes, String mimeType) {
        if (!isAvailable() || imageBytes == null || imageBytes.length == 0 || mimeType == null || mimeType.isBlank()) {
            return "";
        }

        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(geminiUri())
                    .timeout(Duration.ofSeconds(30))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody(imageBytes, mimeType)))
                    .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                return "";
            }
            return parseResponse(response.body());
        } catch (IOException | RuntimeException exception) {
            return "";
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            return "";
        }
    }

    String requestBody(byte[] imageBytes, String mimeType) throws IOException {
        String encodedImage = Base64.getEncoder().encodeToString(imageBytes);
        return objectMapper.writeValueAsString(new GeminiRequest(List.of(
                new Content(List.of(
                        new Part(new InlineData(mimeType, encodedImage), null),
                        new Part(null, OCR_PROMPT)
                ))
        )));
    }

    String parseResponse(String responseBody) throws IOException {
        JsonNode root = objectMapper.readTree(responseBody);
        String text = root.path("candidates")
                .path(0)
                .path("content")
                .path("parts")
                .path(0)
                .path("text")
                .asText("");
        return stripFence(text);
    }

    private URI geminiUri() {
        String encodedModel = URLEncoder.encode(model, StandardCharsets.UTF_8);
        String encodedKey = URLEncoder.encode(apiKey, StandardCharsets.UTF_8);
        return URI.create("https://generativelanguage.googleapis.com/v1beta/models/"
                + encodedModel
                + ":generateContent?key="
                + encodedKey);
    }

    private String stripFence(String text) {
        String trimmed = text == null ? "" : text.trim();
        if (trimmed.startsWith("```") && trimmed.endsWith("```")) {
            int firstLineBreak = trimmed.indexOf('\n');
            if (firstLineBreak >= 0) {
                return trimmed.substring(firstLineBreak + 1, trimmed.length() - 3).trim();
            }
            return trimmed.substring(3, trimmed.length() - 3).trim();
        }
        return trimmed;
    }

    private record GeminiRequest(List<Content> contents) {
    }

    private record Content(List<Part> parts) {
    }

    @JsonInclude(JsonInclude.Include.NON_NULL)
    private record Part(InlineData inlineData, String text) {
    }

    private record InlineData(String mimeType, String data) {
    }
}
