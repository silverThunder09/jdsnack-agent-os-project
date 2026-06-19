package com.jdsnack.sentence;

import com.jdsnack.common.ApiResponse;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class SentencePreviewController {

    private final SentencePreviewService sentencePreviewService;

    public SentencePreviewController(SentencePreviewService sentencePreviewService) {
        this.sentencePreviewService = sentencePreviewService;
    }

    @PostMapping("/api/sentence/preview")
    public ApiResponse<SentencePreviewResponse> preview(
            @RequestBody(required = false) SentencePreviewRequest request
    ) {
        return ApiResponse.success(sentencePreviewService.preview(request));
    }
}
