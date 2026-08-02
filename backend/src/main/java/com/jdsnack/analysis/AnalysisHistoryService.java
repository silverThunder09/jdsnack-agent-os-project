package com.jdsnack.analysis;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import com.jdsnack.common.ErrorDetail;
import com.jdsnack.diagnose.DiagnoseRequest;
import com.jdsnack.diagnose.DiagnoseService;
import com.jdsnack.diagnose.DiagnosisResultResponse;
import com.jdsnack.diagnose.ResumeExtractionService;
import com.jdsnack.match.MatchPreviewRequest;
import com.jdsnack.match.MatchPreviewResponse;
import com.jdsnack.match.MatchPreviewService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.springframework.web.multipart.MultipartFile;

@Service
public class AnalysisHistoryService {

    private final AnalysisHistoryRepository historyRepository;
    private final AnalysisFeedbackRepository feedbackRepository;
    private final AnalysisInputSnapshotRepository snapshotRepository;
    private final AnalysisInputSnapshotService snapshotService;
    private final DiagnoseService diagnoseService;
    private final MatchPreviewService matchPreviewService;
    private final ResumeExtractionService resumeExtractionService;
    private final ObjectMapper objectMapper;

    public AnalysisHistoryService(
            AnalysisHistoryRepository historyRepository,
            AnalysisFeedbackRepository feedbackRepository,
            AnalysisInputSnapshotRepository snapshotRepository,
            AnalysisInputSnapshotService snapshotService,
            DiagnoseService diagnoseService,
            MatchPreviewService matchPreviewService,
            ResumeExtractionService resumeExtractionService,
            ObjectMapper objectMapper
    ) {
        this.historyRepository = historyRepository;
        this.feedbackRepository = feedbackRepository;
        this.snapshotRepository = snapshotRepository;
        this.snapshotService = snapshotService;
        this.diagnoseService = diagnoseService;
        this.matchPreviewService = matchPreviewService;
        this.resumeExtractionService = resumeExtractionService;
        this.objectMapper = objectMapper;
    }

    public AnalysisHistoryResponse create(String userId, AnalysisHistoryCreateRequest request) {
        AnalysisInputSnapshot snapshot = createSnapshot(userId, request);
        return runAnalysis(userId, snapshot);
    }

    public AnalysisHistoryResponse createFile(
            String userId,
            MultipartFile resumeFile,
            AnalysisHistoryCreateRequest request
    ) {
        if (resumeFile == null || resumeFile.isEmpty()) {
            throw new ApiException(ErrorCode.FILE_TEXT_EXTRACTION_FAILED);
        }

        String extractedResumeText = resumeExtractionService.extractText(resumeFile);
        return create(userId, new AnalysisHistoryCreateRequest(extractedResumeText, request.jd()));
    }

    public List<AnalysisHistorySummaryResponse> list(String userId) {
        return historyRepository.findAllByUserId(userId).stream()
                .map(history -> toSummary(history, snapshotFor(history, userId)))
                .toList();
    }

    public AnalysisHistoryResponse get(String userId, String historyId) {
        AnalysisHistory history = findHistory(userId, historyId);
        return toResponse(
                history,
                snapshotFor(history, userId),
                feedbackRepository.findByHistoryIdAndUserId(historyId, userId).orElse(null)
        );
    }

    @Transactional
    public AnalysisFeedbackResponse submitFeedback(
            String userId,
            String historyId,
            AnalysisFeedbackRequest request
    ) {
        AnalysisHistory history = findHistory(userId, historyId);
        if (history.status() != AnalysisHistoryStatus.SUCCEEDED) {
            throw new ApiException(ErrorCode.ANALYSIS_NOT_COMPLETED);
        }

        AnalysisFeedbackRating rating = parseRating(request);
        String comment = normalizeComment(request.comment());

        Instant now = Instant.now();
        AnalysisFeedback saved = feedbackRepository.upsert(new AnalysisFeedback(
                UUID.randomUUID().toString(),
                historyId,
                userId,
                rating,
                comment,
                now,
                now
        ));

        return new AnalysisFeedbackResponse(
                saved.historyId(),
                saved.rating(),
                saved.comment(),
                saved.updatedAt()
        );
    }

    private AnalysisFeedbackRating parseRating(AnalysisFeedbackRequest request) {
        if (request == null || isBlank(request.rating())) {
            throw new ApiException(ErrorCode.INVALID_FEEDBACK_INPUT);
        }

        try {
            return AnalysisFeedbackRating.valueOf(request.rating().trim().toUpperCase());
        } catch (IllegalArgumentException exception) {
            throw new ApiException(ErrorCode.INVALID_FEEDBACK_INPUT);
        }
    }

    private String normalizeComment(String comment) {
        if (comment == null) {
            return null;
        }
        if (comment.length() > AnalysisFeedback.COMMENT_MAX_LENGTH) {
            throw new ApiException(ErrorCode.INVALID_FEEDBACK_INPUT);
        }
        return comment.isBlank() ? null : comment;
    }

    public AnalysisHistoryResponse retry(String userId, String historyId) {
        AnalysisHistory original = findHistory(userId, historyId);
        AnalysisInputSnapshot originalSnapshot = snapshotFor(original, userId);
        AnalysisInputSnapshot retrySnapshot = snapshotRepository.save(new AnalysisInputSnapshot(
                UUID.randomUUID().toString(),
                userId,
                originalSnapshot.resumeText(),
                originalSnapshot.jdInputType(),
                originalSnapshot.jdText(),
                originalSnapshot.sourceUrl(),
                originalSnapshot.sourceSite(),
                originalSnapshot.fetchMode(),
                Instant.now()
        ));
        return runAnalysis(userId, retrySnapshot);
    }

    @Transactional
    public void delete(String userId, String historyId) {
        AnalysisHistory history = findHistory(userId, historyId);
        feedbackRepository.deleteByHistoryIdAndUserId(history.id(), userId);
        if (!historyRepository.deleteByIdAndUserId(history.id(), userId)) {
            throw new ApiException(ErrorCode.ANALYSIS_HISTORY_NOT_FOUND);
        }
        if (!snapshotRepository.deleteByIdAndUserId(history.snapshotId(), userId)) {
            throw new ApiException(ErrorCode.ANALYSIS_HISTORY_NOT_FOUND);
        }
    }

    private AnalysisHistoryResponse runAnalysis(String userId, AnalysisInputSnapshot snapshot) {
        Instant now = Instant.now();
        AnalysisHistory running = historyRepository.save(new AnalysisHistory(
                UUID.randomUUID().toString(),
                userId,
                snapshot.id(),
                AnalysisHistoryStatus.RUNNING,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                now,
                now
        ));

        DiagnosisResultResponse diagnosis = null;
        AnalysisExecutionVersion diagnosisExecutionVersion = null;
        try {
            diagnosis = diagnoseService.diagnose(new DiagnoseRequest(snapshot.resumeText()));
            diagnosisExecutionVersion = diagnoseService.executionVersion();
            MatchPreviewResponse match = matchPreviewService.preview(new MatchPreviewRequest(
                    new MatchPreviewRequest.ResumeSource("TEXT", snapshot.resumeText()),
                    snapshot.jdText(),
                    snapshot.sourceUrl()
            ));
            AnalysisExecutionVersion matchExecutionVersion = matchPreviewService.executionVersion();
            AnalysisHistory succeeded = historyRepository.markSucceeded(
                    running.id(),
                    userId,
                    writeJson(diagnosis),
                    diagnosisExecutionVersion,
                    writeJson(match),
                    matchExecutionVersion
            );
            return toResponse(succeeded, snapshot);
        } catch (ApiException exception) {
            AnalysisHistory failed = failHistory(
                    running,
                    userId,
                    diagnosis,
                    diagnosisExecutionVersion,
                    exception.errorCode().name(),
                    exception.errorCode().message()
            );
            return toResponse(failed, snapshot);
        } catch (RuntimeException exception) {
            AnalysisHistory failed = failHistory(
                    running,
                    userId,
                    diagnosis,
                    diagnosisExecutionVersion,
                    ErrorCode.INTERNAL_ERROR.name(),
                    ErrorCode.INTERNAL_ERROR.message()
            );
            return toResponse(failed, snapshot);
        }
    }

    private AnalysisHistory failHistory(
            AnalysisHistory running,
            String userId,
            DiagnosisResultResponse diagnosis,
            AnalysisExecutionVersion diagnosisExecutionVersion,
            String failureCode,
        String failureMessage
    ) {
        if (diagnosis != null && diagnosisExecutionVersion != null) {
            return historyRepository.markFailedWithDiagnosisExecutionVersion(
                    running.id(),
                    userId,
                    diagnosisExecutionVersion,
                    failureCode,
                    failureMessage
            );
        }
        return historyRepository.markFailed(running.id(), userId, failureCode, failureMessage);
    }

    private AnalysisInputSnapshot createSnapshot(String userId, AnalysisHistoryCreateRequest request) {
        if (request == null || request.jd() == null) {
            throw new ApiException(ErrorCode.INVALID_ANALYSIS_INPUT);
        }

        JdInputType inputType = parseInputType(request.jd().inputType());
        if (inputType == JdInputType.SARAMIN_URL
                && isBlank(request.jd().text())
                && !isBlank(request.jd().sourceUrl())) {
            return snapshotService.saveSaraminUrlInput(userId, request.resumeText(), request.jd().sourceUrl());
        }

        return snapshotService.saveResolvedInput(
                userId,
                request.resumeText(),
                inputType,
                request.jd().text(),
                request.jd().sourceUrl(),
                request.jd().sourceSite(),
                null
        );
    }

    private JdInputType parseInputType(String inputType) {
        if (inputType == null) {
            return JdInputType.TEXT;
        }

        try {
            return JdInputType.valueOf(inputType.trim().toUpperCase());
        } catch (IllegalArgumentException exception) {
            throw new ApiException(ErrorCode.INVALID_ANALYSIS_INPUT);
        }
    }

    private AnalysisHistory findHistory(String userId, String historyId) {
        return historyRepository.findByIdAndUserId(historyId, userId)
                .orElseThrow(() -> new ApiException(ErrorCode.ANALYSIS_HISTORY_NOT_FOUND));
    }

    private AnalysisInputSnapshot snapshotFor(AnalysisHistory history, String userId) {
        return snapshotRepository.findByIdAndUserId(history.snapshotId(), userId)
                .orElseThrow(() -> new ApiException(ErrorCode.ANALYSIS_HISTORY_NOT_FOUND));
    }

    private AnalysisHistoryResponse toResponse(AnalysisHistory history, AnalysisInputSnapshot snapshot) {
        return toResponse(history, snapshot, null);
    }

    private AnalysisHistoryResponse toResponse(
            AnalysisHistory history,
            AnalysisInputSnapshot snapshot,
            AnalysisFeedback feedback
    ) {
        return new AnalysisHistoryResponse(
                history.id(),
                history.status(),
                history.createdAt(),
                new AnalysisHistoryInputResponse(
                        snapshot.resumeText(),
                        snapshot.jdInputType(),
                        snapshot.jdText(),
                        snapshot.sourceUrl(),
                        snapshot.sourceSite()
                ),
                readResult(history),
                failure(history),
                feedback == null
                        ? null
                        : new AnalysisHistoryFeedbackResponse(
                                feedback.rating(),
                                feedback.comment(),
                                feedback.updatedAt()
                        )
        );
    }

    private AnalysisHistorySummaryResponse toSummary(AnalysisHistory history, AnalysisInputSnapshot snapshot) {
        AnalysisHistoryResult result = readResult(history);
        String summary = result != null && result.diagnosis() != null
                ? result.diagnosis().summary()
                : history.failureMessage();
        String label = snapshot.sourceSite() == null ? "직접 입력 JD" : snapshot.sourceSite();
        return new AnalysisHistorySummaryResponse(
                history.id(),
                history.status(),
                history.createdAt(),
                label,
                snapshot.sourceUrl(),
                summary
        );
    }

    private AnalysisHistoryResult readResult(AnalysisHistory history) {
        if (history.diagnosisJson() == null && history.matchJson() == null) {
            return null;
        }

        try {
            return new AnalysisHistoryResult(
                    history.diagnosisJson() == null
                            ? null
                            : objectMapper.readValue(history.diagnosisJson(), DiagnosisResultResponse.class),
                    history.matchJson() == null
                            ? null
                            : objectMapper.readValue(history.matchJson(), MatchPreviewResponse.class)
            );
        } catch (JsonProcessingException exception) {
            throw new ApiException(ErrorCode.INTERNAL_ERROR, exception);
        }
    }

    private ErrorDetail failure(AnalysisHistory history) {
        if (history.failureCode() == null) {
            return null;
        }
        return new ErrorDetail(history.failureCode(), history.failureMessage());
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException exception) {
            throw new ApiException(ErrorCode.INTERNAL_ERROR, exception);
        }
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
