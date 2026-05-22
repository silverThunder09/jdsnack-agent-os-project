package com.jdsnack.diagnose;

import org.springframework.stereotype.Component;

@Component
public class TextNormalizer {

    public String normalize(String text) {
        return text == null ? "" : text.trim().replaceAll("\\s+", " ");
    }
}
