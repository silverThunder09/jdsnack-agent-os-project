package com.jdsnack.jd;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import javax.net.ssl.SSLSession;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpHeaders;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class GeminiJdImageOcrTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void sendsInlineImageAndExtractsPlainTextWithoutNetwork() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        GeminiJdImageOcr ocr = new GeminiJdImageOcr(objectMapper, httpClient, "test-key", "test-model");
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(response(200, """
                        {"candidates":[{"content":{"parts":[{"text":"주요업무 Java API 개발 및 운영 경험이 필요합니다. 자격요건 Spring Boot 활용 경험을 우대합니다."}]}}]}
                        """));

        String result = ocr.extractText(new byte[]{1, 2, 3}, "image/png");

        assertThat(result).contains("Java API 개발");
        var requestCaptor = org.mockito.ArgumentCaptor.forClass(HttpRequest.class);
        verify(httpClient).send(requestCaptor.capture(), any(HttpResponse.BodyHandler.class));
        JsonNode body = objectMapper.readTree(requestCaptor.getValue().bodyPublisher().orElseThrow()
                .contentLength() > 0 ? ocr.requestBody(new byte[]{1, 2, 3}, "image/png") : "");
        JsonNode parts = body.path("contents").path(0).path("parts");
        assertThat(parts.path(0).path("inlineData").path("mimeType").asText()).isEqualTo("image/png");
        assertThat(parts.path(0).path("inlineData").path("data").asText()).isEqualTo("AQID");
        assertThat(parts.path(1).path("text").asText()).contains("plain text only");
    }

    @Test
    void missingApiKeySkipsGeminiCall() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        GeminiJdImageOcr ocr = new GeminiJdImageOcr(objectMapper, httpClient, " ", "test-model");

        assertThat(ocr.isAvailable()).isFalse();
        assertThat(ocr.extractText(new byte[]{1}, "image/png")).isEmpty();
        verify(httpClient, never()).send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class));
    }

    private HttpResponse<String> response(int statusCode, String body) {
        return new TestResponse<>(statusCode, body, URI.create("https://generativelanguage.googleapis.com"));
    }

    private record TestResponse<T>(int statusCode, T body, URI uri) implements HttpResponse<T> {
        @Override
        public HttpRequest request() {
            return HttpRequest.newBuilder().uri(uri).build();
        }

        @Override
        public Optional<HttpResponse<T>> previousResponse() {
            return Optional.empty();
        }

        @Override
        public HttpHeaders headers() {
            return HttpHeaders.of(java.util.Map.of(), (a, b) -> true);
        }

        @Override
        public Optional<SSLSession> sslSession() {
            return Optional.empty();
        }

        @Override
        public HttpClient.Version version() {
            return HttpClient.Version.HTTP_1_1;
        }
    }
}
