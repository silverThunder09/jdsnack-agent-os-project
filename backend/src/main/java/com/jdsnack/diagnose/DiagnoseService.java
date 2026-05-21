package com.jdsnack.diagnose;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import org.springframework.stereotype.Service;

@Service
public class DiagnoseService {

    static final ErrorCode NOT_ENABLED = ErrorCode.AI_ANALYSIS_NOT_ENABLED;

    private static final int MIN_RESUME_LENGTH = 50;
    private static final int MAX_RESUME_LENGTH = 10_000;

    public void validate(DiagnoseRequest request) {
        if (request == null || request.resumeText() == null || request.resumeText().trim().isEmpty()) {
            throw new ApiException(ErrorCode.EMPTY_RESUME);
        }

        String trimmedResumeText = request.resumeText().trim();
        int length = trimmedResumeText.length();

        if (length < MIN_RESUME_LENGTH) {
            throw new ApiException(ErrorCode.TEXT_TOO_SHORT);
        }

        if (length > MAX_RESUME_LENGTH) {
            throw new ApiException(ErrorCode.TEXT_TOO_LONG);
        }
    }
}
