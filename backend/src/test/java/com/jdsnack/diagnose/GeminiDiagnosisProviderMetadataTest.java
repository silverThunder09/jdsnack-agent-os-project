package com.jdsnack.diagnose;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.jdsnack.analysis.AnalysisExecutionVersion;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class GeminiDiagnosisProviderMetadataTest {

    @Test
    void reportsTheResolvedModelAndDiagnosisPromptVersion() {
        GeminiDiagnosisProvider provider = new GeminiDiagnosisProvider(
                new ObjectMapper(),
                "test-key",
                "configured-diagnosis-model"
        );

        assertThat(provider.executionVersion())
                .isEqualTo(new AnalysisExecutionVersion("configured-diagnosis-model", "diagnosis-v1"));
    }
}
