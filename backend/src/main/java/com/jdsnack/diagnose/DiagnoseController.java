package com.jdsnack.diagnose;

import com.jdsnack.common.ApiResponse;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
public class DiagnoseController {

    private final DiagnoseService diagnoseService;

    public DiagnoseController(DiagnoseService diagnoseService) {
        this.diagnoseService = diagnoseService;
    }

    @PostMapping("/api/diagnose")
    public ApiResponse<DiagnosisResultResponse> diagnose(@RequestBody(required = false) DiagnoseRequest request) {
        return ApiResponse.success(diagnoseService.diagnose(request));
    }

    @PostMapping("/api/diagnose/file")
    public ApiResponse<DiagnosisResultResponse> diagnoseFile(
            @RequestParam("resumeFile") MultipartFile resumeFile
    ) {
        return ApiResponse.success(diagnoseService.diagnoseFile(resumeFile));
    }
}
