package com.jdsnack.match;

public record MatchPreviewRequest(
        ResumeSource resumeSource,
        String jdText,
        String jdUrl
) {

    public record ResumeSource(
            String type,
            String value
    ) {
    }
}
