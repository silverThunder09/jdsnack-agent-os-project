package com.jdsnack.jd;

public record JdFetchResponse(
        String jdText,
        String sourceUrl,
        String title,
        String fetchMode
) {
}
