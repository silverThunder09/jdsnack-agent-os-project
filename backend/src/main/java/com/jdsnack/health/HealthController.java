package com.jdsnack.health;

import com.jdsnack.common.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HealthController {

    @GetMapping("/api/health")
    public ApiResponse<HealthResponse> health() {
        return ApiResponse.success(new HealthResponse("UP", "JDSnack", "1.0.0"));
    }
}
