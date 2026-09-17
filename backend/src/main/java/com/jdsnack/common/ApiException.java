package com.jdsnack.common;

import java.util.Map;

public class ApiException extends RuntimeException {

    private final ErrorCode errorCode;
    private final Map<String, Object> metadata;

    public ApiException(ErrorCode errorCode) {
        this(errorCode, null, null);
    }

    public ApiException(ErrorCode errorCode, Throwable cause) {
        this(errorCode, null, cause);
    }

    public ApiException(ErrorCode errorCode, Map<String, Object> metadata) {
        this(errorCode, metadata, null);
    }

    private ApiException(ErrorCode errorCode, Map<String, Object> metadata, Throwable cause) {
        super(errorCode.message(), cause);
        this.errorCode = errorCode;
        this.metadata = metadata;
    }

    public ErrorCode errorCode() {
        return errorCode;
    }

    public ErrorDetail toDetail() {
        return new ErrorDetail(errorCode.name(), errorCode.message(), metadata);
    }
}
