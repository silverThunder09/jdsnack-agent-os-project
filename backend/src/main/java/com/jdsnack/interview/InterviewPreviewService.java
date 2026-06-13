package com.jdsnack.interview;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import com.jdsnack.diagnose.DiagnosisMode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class InterviewPreviewService {

    private static final int MIN_RESUME_LENGTH = 50;
    private static final int MAX_RESUME_LENGTH = 10_000;

    private final DiagnosisMode diagnosisMode;
    private final InterviewPreviewProvider stubInterviewPreviewProvider;
    private final InterviewPreviewProvider fixtureInterviewPreviewProvider;
    private final InterviewPreviewProvider geminiInterviewPreviewProvider;

    public InterviewPreviewService(
            @Value("${jdsnack.diagnosis.mode:stub}") String diagnosisMode,
            StubInterviewPreviewProvider stubInterviewPreviewProvider,
            FixtureInterviewPreviewProvider fixtureInterviewPreviewProvider,
            GeminiInterviewPreviewProvider geminiInterviewPreviewProvider
    ) {
        this.diagnosisMode = DiagnosisMode.from(diagnosisMode);
        this.stubInterviewPreviewProvider = stubInterviewPreviewProvider;
        this.fixtureInterviewPreviewProvider = fixtureInterviewPreviewProvider;
        this.geminiInterviewPreviewProvider = geminiInterviewPreviewProvider;
    }

    public InterviewPreviewResponse preview(InterviewPreviewRequest request) {
        validateRequest(request);

        return selectProvider().preview(request);
    }

    private void validateRequest(InterviewPreviewRequest request) {
        if (request == null || request.resumeSource() == null) {
            throw new ApiException(ErrorCode.EMPTY_RESUME);
        }

        String type = normalized(request.resumeSource().type());
        String value = normalized(request.resumeSource().value());

        if (value == null || value.isBlank()) {
            throw new ApiException(ErrorCode.EMPTY_RESUME);
        }

        if (!"TEXT".equals(type) && !"FILE".equals(type)) {
            throw new ApiException(ErrorCode.EMPTY_RESUME);
        }

        if (value.length() < MIN_RESUME_LENGTH) {
            throw new ApiException(ErrorCode.TEXT_TOO_SHORT);
        }

        if (value.length() > MAX_RESUME_LENGTH) {
            throw new ApiException(ErrorCode.TEXT_TOO_LONG);
        }
    }

    private InterviewPreviewProvider selectProvider() {
        return switch (diagnosisMode) {
            case STUB -> stubInterviewPreviewProvider;
            case FIXTURE -> fixtureInterviewPreviewProvider;
            case AI_LOCAL -> geminiInterviewPreviewProvider;
        };
    }

    private String normalized(String value) {
        return value == null ? null : value.trim();
    }
}
