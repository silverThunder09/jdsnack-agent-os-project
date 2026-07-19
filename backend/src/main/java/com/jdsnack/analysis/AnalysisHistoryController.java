package com.jdsnack.analysis;

import com.jdsnack.auth.GoogleAuthService;
import com.jdsnack.common.ApiResponse;
import jakarta.servlet.http.HttpSession;
import org.springframework.http.ResponseEntity;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
public class AnalysisHistoryController {

    private final AnalysisHistoryService historyService;

    public AnalysisHistoryController(AnalysisHistoryService historyService) {
        this.historyService = historyService;
    }

    @PostMapping("/api/analysis-histories")
    public ApiResponse<AnalysisHistoryResponse> create(
            @RequestBody(required = false) AnalysisHistoryCreateRequest request,
            HttpSession session
    ) {
        return ApiResponse.success(historyService.create(userId(session), request));
    }

    @PostMapping(value = "/api/analysis-histories/file", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ApiResponse<AnalysisHistoryResponse> createFile(
            @RequestPart("resumeFile") MultipartFile resumeFile,
            @RequestParam("inputType") String inputType,
            @RequestParam(value = "text", required = false) String text,
            @RequestParam(value = "sourceUrl", required = false) String sourceUrl,
            @RequestParam(value = "sourceSite", required = false) String sourceSite,
            HttpSession session
    ) {
        AnalysisHistoryCreateRequest request = new AnalysisHistoryCreateRequest(
                null,
                new AnalysisHistoryCreateRequest.JdInput(inputType, text, sourceUrl, sourceSite)
        );
        return ApiResponse.success(historyService.createFile(userId(session), resumeFile, request));
    }

    @GetMapping("/api/analysis-histories")
    public ApiResponse<List<AnalysisHistorySummaryResponse>> list(HttpSession session) {
        return ApiResponse.success(historyService.list(userId(session)));
    }

    @GetMapping("/api/analysis-histories/{historyId}")
    public ApiResponse<AnalysisHistoryResponse> get(
            @PathVariable String historyId,
            HttpSession session
    ) {
        return ApiResponse.success(historyService.get(userId(session), historyId));
    }

    @PostMapping("/api/analysis-histories/{historyId}/retry")
    public ApiResponse<AnalysisHistoryResponse> retry(
            @PathVariable String historyId,
            HttpSession session
    ) {
        return ApiResponse.success(historyService.retry(userId(session), historyId));
    }

    @DeleteMapping("/api/analysis-histories/{historyId}")
    public ResponseEntity<Void> delete(
            @PathVariable String historyId,
            HttpSession session
    ) {
        historyService.delete(userId(session), historyId);
        return ResponseEntity.noContent().build();
    }

    private String userId(HttpSession session) {
        return (String) session.getAttribute(GoogleAuthService.SESSION_USER_ID);
    }
}
