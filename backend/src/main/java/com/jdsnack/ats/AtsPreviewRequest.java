package com.jdsnack.ats;

public record AtsPreviewRequest(
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
