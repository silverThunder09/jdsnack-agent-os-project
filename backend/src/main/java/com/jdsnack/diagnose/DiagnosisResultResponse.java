package com.jdsnack.diagnose;

import java.util.List;

public record DiagnosisResultResponse(
        int score,
        String summary,
        List<String> strengths,
        List<String> improvements,
        String sourceText
) {
}
