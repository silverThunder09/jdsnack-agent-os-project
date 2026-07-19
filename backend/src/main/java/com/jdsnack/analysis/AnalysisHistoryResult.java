package com.jdsnack.analysis;

import com.jdsnack.diagnose.DiagnosisResultResponse;
import com.jdsnack.match.MatchPreviewResponse;

public record AnalysisHistoryResult(
        DiagnosisResultResponse diagnosis,
        MatchPreviewResponse match
) {
}
