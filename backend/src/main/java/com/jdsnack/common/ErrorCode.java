package com.jdsnack.common;

import org.springframework.http.HttpStatus;

public enum ErrorCode {
    EMPTY_RESUME(
            HttpStatus.BAD_REQUEST,
            "이력서 내용을 입력해주세요."
    ),
    TEXT_TOO_SHORT(
            HttpStatus.BAD_REQUEST,
            "이력서 내용이 너무 짧습니다. 최소 50자 이상 입력해주세요."
    ),
    TEXT_TOO_LONG(
            HttpStatus.BAD_REQUEST,
            "이력서 내용이 너무 깁니다. 10,000자 이내로 입력해주세요."
    ),
    AI_ANALYSIS_NOT_ENABLED(
            HttpStatus.NOT_IMPLEMENTED,
            "AI 분석 기능은 준비 중입니다. 현재는 이력서 입력 검증만 가능합니다."
    ),
    INTERNAL_ERROR(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
    );

    private final HttpStatus status;
    private final String message;

    ErrorCode(HttpStatus status, String message) {
        this.status = status;
        this.message = message;
    }

    public HttpStatus status() {
        return status;
    }

    public String message() {
        return message;
    }

    public ErrorDetail toDetail() {
        return new ErrorDetail(name(), message);
    }
}
