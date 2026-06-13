package com.jdsnack.interview;

import com.jdsnack.common.ApiResponse;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class InterviewPreviewController {

    private final InterviewPreviewService interviewPreviewService;

    public InterviewPreviewController(InterviewPreviewService interviewPreviewService) {
        this.interviewPreviewService = interviewPreviewService;
    }

    @PostMapping("/api/interview/preview")
    public ApiResponse<InterviewPreviewResponse> preview(@RequestBody(required = false) InterviewPreviewRequest request) {
        return ApiResponse.success(interviewPreviewService.preview(request));
    }
}
