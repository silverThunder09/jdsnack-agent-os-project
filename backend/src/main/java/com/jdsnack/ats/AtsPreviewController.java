package com.jdsnack.ats;

import com.jdsnack.common.ApiResponse;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class AtsPreviewController {

    private final AtsPreviewService atsPreviewService;

    public AtsPreviewController(AtsPreviewService atsPreviewService) {
        this.atsPreviewService = atsPreviewService;
    }

    @PostMapping("/api/ats/preview")
    public ApiResponse<AtsPreviewResponse> preview(@RequestBody(required = false) AtsPreviewRequest request) {
        return ApiResponse.success(atsPreviewService.preview(request));
    }
}
