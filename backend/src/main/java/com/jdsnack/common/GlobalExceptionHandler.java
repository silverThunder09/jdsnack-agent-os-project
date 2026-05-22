package com.jdsnack.common;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.resource.NoResourceFoundException;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<ApiResponse<Void>> handleApiException(ApiException exception) {
        ErrorCode errorCode = exception.errorCode();

        return ResponseEntity
                .status(errorCode.status())
                .body(ApiResponse.failure(errorCode.toDetail()));
    }

    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ApiResponse<Void>> handleNoResourceFound(NoResourceFoundException exception) {
        ErrorCode errorCode = ErrorCode.NOT_FOUND;

        return ResponseEntity
                .status(errorCode.status())
                .body(ApiResponse.failure(errorCode.toDetail()));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleException(Exception exception) {
        ErrorCode errorCode = ErrorCode.INTERNAL_ERROR;

        return ResponseEntity
                .status(errorCode.status())
                .body(ApiResponse.failure(errorCode.toDetail()));
    }
}
