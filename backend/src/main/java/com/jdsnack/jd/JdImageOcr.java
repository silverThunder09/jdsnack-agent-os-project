package com.jdsnack.jd;

public interface JdImageOcr {

    default boolean isAvailable() {
        return true;
    }

    String extractText(byte[] imageBytes, String mimeType);
}
