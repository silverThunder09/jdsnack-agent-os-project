package com.jdsnack.health;

import com.jdsnack.common.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HealthController {

    @GetMapping("/")
    public ApiResponse<RootResponse> root() {
        return ApiResponse.success(new RootResponse(
                "JDSnack",
                "RUNNING",
                "/api/health",
                "/api/diagnose"
        ));
    }

    @GetMapping("/api/health")
    public ApiResponse<HealthResponse> health() {
        return ApiResponse.success(new HealthResponse("UP", "JDSnack", "1.0.0"));
    }
}
