package com.jdsnack.sentence;

public record SentenceEdit(
        String original,
        String improved,
        String reason
) {
}
