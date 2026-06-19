package com.jdsnack.sentence;

import java.util.List;

public record SentencePreviewResponse(List<SentenceEdit> edits) {

    private static final int MAX_EDITS = 8;

    public SentencePreviewResponse {
        edits = edits == null ? List.of() : edits.stream().limit(MAX_EDITS).toList();
    }
}
