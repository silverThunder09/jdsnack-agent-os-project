package com.jdsnack.common;
import org.junit.jupiter.api.*;
import org.springframework.http.*;
import org.springframework.web.multipart.*;
import static org.assertj.core.api.Assertions.assertThat;
class GlobalExceptionHandlerMultipartTest {
    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();
    @Test void mapsMultipartErrorsToBadRequestValidationError() {
        assertValidationError(new MaxUploadSizeExceededException(1024L));
        assertValidationError(new MultipartException("invalid multipart request"));
    }
    private void assertValidationError(MultipartException exception) { ResponseEntity<ApiResponse<Void>> response = handler.handleMultipartException(exception); assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST); assertThat(response.getBody()).isNotNull(); assertThat(response.getBody().error().code()).isEqualTo(ErrorCode.FILE_TEXT_EXTRACTION_FAILED.name()); }
}
