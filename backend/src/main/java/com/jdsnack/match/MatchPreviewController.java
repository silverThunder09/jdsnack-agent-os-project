package com.jdsnack.match;

import com.jdsnack.common.ApiResponse;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class MatchPreviewController {

    private final MatchPreviewService matchPreviewService;

    public MatchPreviewController(MatchPreviewService matchPreviewService) {
        this.matchPreviewService = matchPreviewService;
    }

    @PostMapping("/api/match/preview")
    public ApiResponse<MatchPreviewResponse> preview(@RequestBody(required = false) MatchPreviewRequest request) {
        return ApiResponse.success(matchPreviewService.preview(request));
    }
}
