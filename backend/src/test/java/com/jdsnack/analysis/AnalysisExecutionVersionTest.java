package com.jdsnack.analysis;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThatIllegalArgumentException;

class AnalysisExecutionVersionTest {

    @Test
    void rejectsNullOrBlankModelName() {
        assertInvalid(null, "diagnosis-v1", "modelName must not be blank");
        assertInvalid("", "diagnosis-v1", "modelName must not be blank");
        assertInvalid(" ", "diagnosis-v1", "modelName must not be blank");
    }

    @Test
    void rejectsNullOrBlankPromptVersion() {
        assertInvalid("fixture", null, "promptVersion must not be blank");
        assertInvalid("fixture", "", "promptVersion must not be blank");
        assertInvalid("fixture", " ", "promptVersion must not be blank");
    }

    private void assertInvalid(String modelName, String promptVersion, String message) {
        assertThatIllegalArgumentException()
                .isThrownBy(() -> new AnalysisExecutionVersion(modelName, promptVersion))
                .withMessage(message);
    }
}
