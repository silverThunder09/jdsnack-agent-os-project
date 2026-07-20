package com.jdsnack.ats;

import java.util.List;

public record AtsPreviewResponse(
        int atsScore,
        String summary,
        List<String> strengths,
        List<String> risks,
        List<String> suggestions,
        List<String> matchedKeywords,
        List<String> missingKeywords,
        List<FormatCheck> formatChecks
) {

    public record FormatCheck(
            String label,
            boolean passed,
            String message
    ) {
    }
}
