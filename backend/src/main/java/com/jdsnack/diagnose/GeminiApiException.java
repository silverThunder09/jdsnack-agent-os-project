package com.jdsnack.diagnose;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;

public class GeminiApiException extends ApiException {

    public GeminiApiException(ErrorCode errorCode) {
        super(errorCode);
    }

    public GeminiApiException(ErrorCode errorCode, Throwable cause) {
        super(errorCode, cause);
    }
}
