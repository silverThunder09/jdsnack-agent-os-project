package com.jdsnack.interview;

public record InterviewPreviewRequest(
        ResumeSource resumeSource,
        String jobTitle,
        String jdText
) {

    public record ResumeSource(
            String type,
            String value
    ) {
    }
}
