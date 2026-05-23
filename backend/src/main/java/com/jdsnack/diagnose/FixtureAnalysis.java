package com.jdsnack.diagnose;

import java.util.List;

public record FixtureAnalysis(
        String fixtureKey,
        int score,
        String summary,
        List<String> strengths,
        List<String> improvements
) {

    public DiagnosisResultResponse toResponse(String sourceText) {
        return new DiagnosisResultResponse(score, summary, strengths, improvements, sourceText);
    }
}
