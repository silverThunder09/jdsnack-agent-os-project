package com.jdsnack.jd;

import com.jdsnack.common.ApiResponse;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class JdFetchController {

    private final JdFetchService jdFetchService;

    public JdFetchController(JdFetchService jdFetchService) {
        this.jdFetchService = jdFetchService;
    }

    @PostMapping("/api/jd/fetch")
    public ApiResponse<JdFetchResponse> fetch(@RequestBody(required = false) JdFetchRequest request) {
        return ApiResponse.success(jdFetchService.fetch(request));
    }
}
