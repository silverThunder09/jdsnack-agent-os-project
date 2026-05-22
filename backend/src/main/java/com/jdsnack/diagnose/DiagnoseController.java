package com.jdsnack.diagnose;

import com.jdsnack.common.ApiResponse;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class DiagnoseController {

    private final DiagnoseService diagnoseService;

    public DiagnoseController(DiagnoseService diagnoseService) {
        this.diagnoseService = diagnoseService;
    }

    @PostMapping("/api/diagnose")
    @ResponseStatus(HttpStatus.NOT_IMPLEMENTED)
    public ApiResponse<Void> diagnose(@RequestBody(required = false) DiagnoseRequest request) {
        diagnoseService.validate(request);

        return ApiResponse.failure(DiagnoseService.NOT_ENABLED.toDetail());
    }
}
