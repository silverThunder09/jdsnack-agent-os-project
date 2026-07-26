package com.jdsnack.diagnose;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.jdsnack.common.ProviderMetadata;
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

        assertThat(provider.providerMetadata())
                .isEqualTo(new ProviderMetadata("configured-diagnosis-model", "diagnosis-v1"));
    }
}
