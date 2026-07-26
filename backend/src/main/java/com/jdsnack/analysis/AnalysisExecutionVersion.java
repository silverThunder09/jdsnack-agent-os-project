package com.jdsnack.analysis;

public record AnalysisExecutionVersion(
        String modelName,
        String promptVersion
) {

    public AnalysisExecutionVersion {
        if (modelName == null || modelName.isBlank()) {
            throw new IllegalArgumentException("modelName must not be blank");
        }
        if (promptVersion == null || promptVersion.isBlank()) {
            throw new IllegalArgumentException("promptVersion must not be blank");
        }
    }
}
