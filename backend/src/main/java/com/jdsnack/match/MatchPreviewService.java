package com.jdsnack.match;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.Locale;

@Service
public class MatchPreviewService {

    private static final int MIN_JD_LENGTH = 50;
    private static final int MAX_JD_LENGTH = 10_000;

    public void preview(MatchPreviewRequest request) {
        validateRequest(request);
        throw new ApiException(ErrorCode.JD_MATCH_PREVIEW_NOT_ENABLED);
    }

    private void validateRequest(MatchPreviewRequest request) {
        if (request == null || request.resumeSource() == null) {
            throw new ApiException(ErrorCode.EMPTY_RESUME);
        }

        validateResumeSource(request.resumeSource());
        validateJdText(request.jdText());
        validateJdUrl(request.jdUrl());
    }

    private void validateResumeSource(MatchPreviewRequest.ResumeSource resumeSource) {
        String type = normalized(resumeSource.type());
        String value = normalized(resumeSource.value());

        if (value == null || value.isBlank()) {
            throw new ApiException(ErrorCode.EMPTY_RESUME);
        }

        if (!"TEXT".equals(type) && !"FILE".equals(type)) {
            throw new ApiException(ErrorCode.EMPTY_RESUME);
        }
    }

    private void validateJdText(String jdText) {
        String normalizedText = normalized(jdText);

        if (normalizedText == null || normalizedText.isBlank()) {
            throw new ApiException(ErrorCode.EMPTY_JD);
        }

        int length = normalizedText.length();
        if (length < MIN_JD_LENGTH) {
            throw new ApiException(ErrorCode.JD_TEXT_TOO_SHORT);
        }

        if (length > MAX_JD_LENGTH) {
            throw new ApiException(ErrorCode.JD_TEXT_TOO_LONG);
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
            String host = uri.getHost();

            if (scheme == null || host == null) {
                throw new ApiException(ErrorCode.INVALID_JD_URL);
            }

            String lowerScheme = scheme.toLowerCase(Locale.ROOT);
            if (!"http".equals(lowerScheme) && !"https".equals(lowerScheme)) {
                throw new ApiException(ErrorCode.INVALID_JD_URL);
            }
        } catch (URISyntaxException exception) {
            throw new ApiException(ErrorCode.INVALID_JD_URL);
        }
    }

    private String normalized(String value) {
        return value == null ? null : value.trim();
    }
}
