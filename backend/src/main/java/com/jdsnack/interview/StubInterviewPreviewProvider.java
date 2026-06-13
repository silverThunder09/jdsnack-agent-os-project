package com.jdsnack.interview;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import org.springframework.stereotype.Component;

@Component
public class StubInterviewPreviewProvider implements InterviewPreviewProvider {

    @Override
    public InterviewPreviewResponse preview(InterviewPreviewRequest request) {
        throw new ApiException(ErrorCode.MOCK_INTERVIEW_NOT_ENABLED);
    }
}
