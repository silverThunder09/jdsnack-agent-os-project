package com.jdsnack.sentence;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import com.jdsnack.diagnose.DiagnosisMode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.Locale;

@Service
public class SentencePreviewService {

    private static final int MIN_TEXT_LENGTH = 50;
    private static final int MAX_TEXT_LENGTH = 10_000;

    private final DiagnosisMode diagnosisMode;
    private final SentencePreviewProvider stubProvider;
    private final SentencePreviewProvider fixtureProvider;
    private final SentencePreviewProvider geminiProvider;

    public SentencePreviewService(
            @Value("${jdsnack.diagnosis.mode:stub}") String diagnosisMode,
            StubSentencePreviewProvider stubProvider,
            FixtureSentencePreviewProvider fixtureProvider,
            GeminiSentencePreviewProvider geminiProvider
    ) {
        this.diagnosisMode = DiagnosisMode.from(diagnosisMode);
        this.stubProvider = stubProvider;
        this.fixtureProvider = fixtureProvider;
        this.geminiProvider = geminiProvider;
    }

    public SentencePreviewResponse preview(SentencePreviewRequest request) {
        validateRequest(request);
        return selectProvider().preview(request);
    }

    private void validateRequest(SentencePreviewRequest request) {
        if (request == null || request.resumeSource() == null) {
            throw new ApiException(ErrorCode.EMPTY_RESUME);
        }

        String type = normalized(request.resumeSource().type());
        String value = normalized(request.resumeSource().value());
        if (value == null || value.isBlank() || (!"TEXT".equals(type) && !"FILE".equals(type))) {
            throw new ApiException(ErrorCode.EMPTY_RESUME);
        }
        validateLength(value, ErrorCode.TEXT_TOO_SHORT, ErrorCode.TEXT_TOO_LONG);

        String jdText = normalized(request.jdText());
        if (jdText == null || jdText.isBlank()) {
            throw new ApiException(ErrorCode.EMPTY_JD);
        }
        validateLength(jdText, ErrorCode.JD_TEXT_TOO_SHORT, ErrorCode.JD_TEXT_TOO_LONG);
        validateJdUrl(request.jdUrl());
    }

    private void validateLength(String value, ErrorCode shortCode, ErrorCode longCode) {
        if (value.length() < MIN_TEXT_LENGTH) {
            throw new ApiException(shortCode);
        }
        if (value.length() > MAX_TEXT_LENGTH) {
            throw new ApiException(longCode);
        }
    }

    private void validateJdUrl(String jdUrl) {
        String normalizedUrl = normalized(jdUrl);
        if (normalizedUrl == null || normalizedUrl.isBlank()) {
            return;
        }

        try {
            URI uri = new URI(normalizedUrl);
            String scheme = uri.getScheme();
            if (scheme == null || uri.getHost() == null
                    || !("http".equals(scheme.toLowerCase(Locale.ROOT))
                    || "https".equals(scheme.toLowerCase(Locale.ROOT)))) {
                throw new ApiException(ErrorCode.INVALID_JD_URL);
            }
        } catch (URISyntaxException exception) {
            throw new ApiException(ErrorCode.INVALID_JD_URL);
        }
    }

    private SentencePreviewProvider selectProvider() {
        return switch (diagnosisMode) {
            case STUB -> stubProvider;
            case FIXTURE -> fixtureProvider;
            case AI_LOCAL -> geminiProvider;
        };
    }

    private String normalized(String value) {
        return value == null ? null : value.trim();
    }
}
