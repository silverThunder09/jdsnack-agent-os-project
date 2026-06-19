package com.jdsnack.sentence;

public record SentencePreviewRequest(
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
