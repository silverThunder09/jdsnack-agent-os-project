package com.jdsnack.analysis;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import com.jdsnack.diagnose.ResumeExtractionService;
import com.jdsnack.diagnose.TextNormalizer;
import com.jdsnack.jd.JdFetchRequest;
import com.jdsnack.jd.JdFetchResponse;
import com.jdsnack.jd.JdFetchService;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.net.URI;
import java.net.URISyntaxException;
import java.time.Instant;
import java.util.UUID;

@Service
public class AnalysisInputSnapshotService {

    private static final int MIN_RESUME_LENGTH = 50;
    private static final int MAX_RESUME_LENGTH = 10_000;
    private static final int MIN_JD_LENGTH = 50;
    private static final int MAX_JD_LENGTH = 10_000;

    private final AnalysisInputSnapshotRepository repository;
    private final ResumeExtractionService resumeExtractionService;
    private final JdFetchService jdFetchService;
    private final TextNormalizer textNormalizer;

    public AnalysisInputSnapshotService(
            AnalysisInputSnapshotRepository repository,
            ResumeExtractionService resumeExtractionService,
            JdFetchService jdFetchService,
            TextNormalizer textNormalizer
    ) {
        this.repository = repository;
        this.resumeExtractionService = resumeExtractionService;
        this.jdFetchService = jdFetchService;
        this.textNormalizer = textNormalizer;
    }

    public AnalysisInputSnapshot saveTextInput(String userId, String resumeText, String jdText) {
        return save(
                userId,
                resumeText,
                JdInputType.TEXT,
                jdText,
                null,
                null,
                null
        );
    }

    public AnalysisInputSnapshot saveFileInput(String userId, MultipartFile resumeFile, String jdText) {
        String extractedText = resumeExtractionService.extractText(resumeFile);
        return saveTextInput(userId, extractedText, jdText);
    }

    public AnalysisInputSnapshot saveSaraminUrlInput(String userId, String resumeText, String jdUrl) {
        JdFetchResponse fetchedJd = jdFetchService.fetch(new JdFetchRequest(jdUrl));
        return save(
                userId,
                resumeText,
                JdInputType.SARAMIN_URL,
                fetchedJd.jdText(),
                fetchedJd.sourceUrl(),
                fetchedJd.sourceSite(),
                fetchedJd.fetchMode()
        );
    }

    public AnalysisInputSnapshot saveResolvedInput(
            String userId,
            String resumeText,
            JdInputType jdInputType,
            String jdText,
            String sourceUrl,
            String sourceSite,
            String fetchMode
    ) {
        return save(userId, resumeText, jdInputType, jdText, sourceUrl, sourceSite, fetchMode);
    }

    private AnalysisInputSnapshot save(
            String userId,
            String resumeText,
            JdInputType jdInputType,
            String jdText,
            String sourceUrl,
            String sourceSite,
            String fetchMode
    ) {
        validateUserId(userId);
        String normalizedResumeText = normalizeResumeText(resumeText);
        String normalizedJdText = normalizeJdText(jdText);
        String normalizedSourceUrl = normalizeSourceUrl(sourceUrl);

        return repository.save(new AnalysisInputSnapshot(
                UUID.randomUUID().toString(),
                userId,
                normalizedResumeText,
                jdInputType,
                normalizedJdText,
                normalizedSourceUrl,
                normalizeOptional(sourceSite),
                normalizeOptional(fetchMode),
                Instant.now()
        ));
    }

    private String normalizeResumeText(String resumeText) {
        String normalized = textNormalizer.normalize(resumeText);
        if (normalized.isBlank()) {
            throw new ApiException(ErrorCode.EMPTY_RESUME);
        }
        validateLength(normalized, MIN_RESUME_LENGTH, MAX_RESUME_LENGTH,
                ErrorCode.TEXT_TOO_SHORT, ErrorCode.TEXT_TOO_LONG);
        return normalized;
    }

    private String normalizeJdText(String jdText) {
        String normalized = textNormalizer.normalize(jdText);
        if (normalized.isBlank()) {
            throw new ApiException(ErrorCode.EMPTY_JD);
        }
        validateLength(normalized, MIN_JD_LENGTH, MAX_JD_LENGTH,
                ErrorCode.JD_TEXT_TOO_SHORT, ErrorCode.JD_TEXT_TOO_LONG);
        return normalized;
    }

    private String normalizeSourceUrl(String sourceUrl) {
        String normalized = normalizeOptional(sourceUrl);
        if (normalized == null) {
            return null;
        }

        try {
            URI uri = new URI(normalized);
            String scheme = uri.getScheme();
            if (uri.getHost() == null || scheme == null
                    || (!"http".equalsIgnoreCase(scheme) && !"https".equalsIgnoreCase(scheme))) {
                throw new ApiException(ErrorCode.INVALID_JD_URL);
            }
        } catch (URISyntaxException exception) {
            throw new ApiException(ErrorCode.INVALID_JD_URL);
        }
        return normalized;
    }

    private void validateLength(
            String value,
            int minimum,
            int maximum,
            ErrorCode shortError,
            ErrorCode longError
    ) {
        if (value.length() < minimum) {
            throw new ApiException(shortError);
        }
        if (value.length() > maximum) {
            throw new ApiException(longError);
        }
    }

    private String normalizeOptional(String value) {
        if (value == null) {
            return null;
        }
        String normalized = value.trim().replaceAll("\\s+", " ");
        return normalized.isBlank() ? null : normalized;
    }

    private void validateUserId(String userId) {
        if (userId == null || userId.isBlank()) {
            throw new ApiException(ErrorCode.AUTHENTICATION_REQUIRED);
        }
    }
}
