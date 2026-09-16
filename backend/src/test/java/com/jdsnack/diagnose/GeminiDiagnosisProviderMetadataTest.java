package com.jdsnack.diagnose;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.jdsnack.analysis.AnalysisExecutionVersion;
import com.jdsnack.common.ErrorCode;
import org.junit.jupiter.api.Test;

import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class GeminiDiagnosisProviderMetadataTest {

    @Test
    void reportsTheResolvedModelAndDiagnosisPromptVersion() {
        GeminiDiagnosisProvider provider = new GeminiDiagnosisProvider(new ObjectMapper(), "test-key", "configured-diagnosis-model");

        assertThat(provider.executionVersion())
                .isEqualTo(new AnalysisExecutionVersion("configured-diagnosis-model", "diagnosis-v1"));
        assertThat(provider.connectTimeout()).isEqualTo(Duration.ofSeconds(10));
        assertThat(provider.requestTimeout()).isEqualTo(Duration.ofSeconds(30));
    }
    @Test
    void appliesOverriddenConnectAndRequestTimeouts() {
        GeminiDiagnosisProvider provider = new GeminiDiagnosisProvider(new ObjectMapper(), "test-key",
                "configured-diagnosis-model", 3, 7);

        assertThat(provider.connectTimeout()).isEqualTo(Duration.ofSeconds(3));
        assertThat(provider.requestTimeout()).isEqualTo(Duration.ofSeconds(7));
    }
    @Test
    void mapsInvalidGeminiResponse() { assertThatThrownBy(() -> new GeminiDiagnosisProvider(new ObjectMapper(), "test-key", "model").parseResponse("{}", "resume")).isInstanceOfSatisfying(GeminiApiException.class, e -> assertThat(e.errorCode()).isEqualTo(ErrorCode.GEMINI_API_RESPONSE_INVALID)); }
    @Test void mapsTimeoutToRequestFailure() throws Exception { var client = org.mockito.Mockito.mock(java.net.http.HttpClient.class); org.mockito.Mockito.doThrow(new java.net.http.HttpTimeoutException("timeout")).when(client).send(org.mockito.ArgumentMatchers.any(java.net.http.HttpRequest.class), org.mockito.ArgumentMatchers.any(java.net.http.HttpResponse.BodyHandler.class)); assertThatThrownBy(() -> new GeminiDiagnosisProvider(new ObjectMapper(), client, "test-key", "model", Duration.ofSeconds(30)).diagnose(UploadedResumeType.TEXT, "resume")).isInstanceOfSatisfying(GeminiApiException.class, e -> assertThat(e.errorCode()).isEqualTo(ErrorCode.GEMINI_API_REQUEST_FAILED)); }
}
