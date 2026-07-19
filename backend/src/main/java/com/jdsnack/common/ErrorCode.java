package com.jdsnack.common;

import org.springframework.http.HttpStatus;

public enum ErrorCode {
    AUTHENTICATION_REQUIRED(
            HttpStatus.UNAUTHORIZED,
            "로그인이 필요합니다."
    ),
    OAUTH_NOT_CONFIGURED(
            HttpStatus.SERVICE_UNAVAILABLE,
            "Google 로그인 설정이 준비되지 않았습니다."
    ),
    OAUTH_STATE_INVALID(
            HttpStatus.BAD_REQUEST,
            "로그인 요청이 만료되었거나 유효하지 않습니다."
    ),
    OAUTH_CALLBACK_FAILED(
            HttpStatus.BAD_GATEWAY,
            "Google 로그인에 실패했습니다. 잠시 후 다시 시도해주세요."
    ),
    OAUTH_PROVIDER_FAILED(
            HttpStatus.BAD_GATEWAY,
            "Google 계정 정보를 확인하지 못했습니다. 잠시 후 다시 시도해주세요."
    ),
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
    EMPTY_JD(
            HttpStatus.BAD_REQUEST,
            "JD 내용을 입력해주세요."
    ),
    JD_TEXT_TOO_SHORT(
            HttpStatus.BAD_REQUEST,
            "JD 내용이 너무 짧습니다. 핵심 자격요건이 드러나도록 더 입력해주세요."
    ),
    JD_TEXT_TOO_LONG(
            HttpStatus.BAD_REQUEST,
            "JD 내용이 너무 깁니다. 핵심 본문만 정리해서 입력해주세요."
    ),
    INVALID_JD_URL(
            HttpStatus.BAD_REQUEST,
            "올바른 JD 링크 형식을 입력해주세요."
    ),
    JD_FETCH_EMPTY_CONTENT(
            HttpStatus.UNPROCESSABLE_ENTITY,
            "JD 링크에서 본문을 충분히 추출하지 못했습니다. JD 텍스트를 직접 붙여넣어 주세요."
    ),
    JD_FETCH_UNSUPPORTED_SOURCE(
            HttpStatus.UNPROCESSABLE_ENTITY,
            "현재 JD 링크 형식은 자동 수집을 지원하지 않습니다. JD 텍스트를 직접 붙여넣어 주세요."
    ),
    JD_FETCH_FAILED(
            HttpStatus.BAD_GATEWAY,
            "JD 링크를 불러오지 못했습니다. 잠시 후 다시 시도해주세요."
    ),
    UNSUPPORTED_FILE_TYPE(
            HttpStatus.BAD_REQUEST,
            "PDF 또는 DOCX 파일만 업로드할 수 있습니다."
    ),
    FILE_TEXT_EXTRACTION_FAILED(
            HttpStatus.BAD_REQUEST,
            "파일에서 텍스트를 추출하지 못했습니다. 다른 파일로 다시 시도해주세요."
    ),
    GEMINI_API_KEY_MISSING(
            HttpStatus.SERVICE_UNAVAILABLE,
            "로컬 AI 분석 설정이 비어 있습니다. GEMINI_API_KEY를 확인해주세요."
    ),
    GEMINI_API_REQUEST_FAILED(
            HttpStatus.BAD_GATEWAY,
            "Gemini AI 분석 요청에 실패했습니다. 잠시 후 다시 시도해주세요."
    ),
    GEMINI_API_RESPONSE_INVALID(
            HttpStatus.BAD_GATEWAY,
            "Gemini AI 응답 형식을 해석하지 못했습니다. 다시 시도해주세요."
    ),
    AI_ANALYSIS_NOT_ENABLED(
            HttpStatus.NOT_IMPLEMENTED,
            "AI 분석 기능은 준비 중입니다. 현재는 이력서 입력 검증만 가능합니다."
    ),
    JD_MATCH_PREVIEW_NOT_ENABLED(
            HttpStatus.NOT_IMPLEMENTED,
            "JD 비교 분석 기능은 준비 중입니다. 현재는 JD 입력 검증만 가능합니다."
    ),
    MOCK_INTERVIEW_NOT_ENABLED(
            HttpStatus.NOT_IMPLEMENTED,
            "모의 면접 질문 생성 기능은 준비 중입니다."
    ),
    INVALID_ANALYSIS_INPUT(
            HttpStatus.BAD_REQUEST,
            "분석 입력을 확인해주세요."
    ),
    ANALYSIS_HISTORY_NOT_FOUND(
            HttpStatus.NOT_FOUND,
            "요청한 분석 이력을 찾을 수 없습니다."
    ),
    INTERVIEW_QUESTION_GENERATION_FAILED(
            HttpStatus.BAD_GATEWAY,
            "모의 면접 질문 생성에 실패했습니다. 잠시 후 다시 시도해주세요."
    ),
    FIXTURE_NOT_FOUND(
            HttpStatus.NOT_FOUND,
            "테스트 분석 결과를 찾지 못했습니다. 다른 샘플로 다시 시도해주세요."
    ),
    NOT_FOUND(
            HttpStatus.NOT_FOUND,
            "요청한 경로를 찾을 수 없습니다."
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
