package com.jdsnack.interview;

import java.util.List;

public record InterviewPreviewResponse(
        List<Question> questions,
        String strategy,
        String summary
) {

    public record Question(
            String question,
            String category,
            String keypoints
    ) {
    }
}
