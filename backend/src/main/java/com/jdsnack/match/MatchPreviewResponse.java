package com.jdsnack.match;

import java.util.List;

public record MatchPreviewResponse(
        int matchingScore,
        String summary,
        List<String> strengths,
        List<String> gaps,
        List<String> suggestions
) {
}
