package com.jdsnack.schema;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * ADR-019는 운영 영속 저장소를 PostgreSQL로 확정했고, 스키마 변경은 PostgreSQL과 H2 양쪽에서
 * 동작해야 한다고 규정한다. 그러나 로컬·테스트가 H2만 사용하기 때문에 PostgreSQL에 없는 타입이
 * 들어와도 어떤 게이트에도 걸리지 않았다(Issue #175, 회귀 커밋 #144).
 *
 * <p>이 테스트는 그 빈 구멍을 막는다. schema.sql이 PostgreSQL에 존재하지 않는 타입을 쓰면 실패한다.
 */
class SchemaPortabilityTest {

    /** PostgreSQL에 없는 타입 → 양쪽에서 동작하는 대체 타입. */
    private static final Map<String, String> UNSUPPORTED_BY_POSTGRES = new LinkedHashMap<>(Map.of(
            "CLOB", "TEXT",
            "BLOB", "BYTEA",
            "VARCHAR2", "VARCHAR",
            "NUMBER", "NUMERIC",
            "DATETIME", "TIMESTAMP"
    ));

    @Test
    void schemaUsesOnlyTypesAvailableInBothPostgresAndH2() throws IOException {
        String schema = readSchema();

        for (Map.Entry<String, String> entry : UNSUPPORTED_BY_POSTGRES.entrySet()) {
            String unsupported = entry.getKey();
            Matcher matcher = Pattern
                    .compile("\\b" + unsupported + "\\b", Pattern.CASE_INSENSITIVE)
                    .matcher(schema);

            assertThat(matcher.find())
                    .withFailMessage(
                            "schema.sql이 PostgreSQL에 없는 타입 '%s'을(를) 사용합니다. '%s'로 바꾸세요. "
                                    + "H2는 '%s'을(를) 받아주지만 PostgreSQL에서는 스키마 생성이 실패합니다. "
                                    + "근거: ADR-019, Issue #175.",
                            unsupported, entry.getValue(), unsupported)
                    .isFalse();
        }
    }

    private String readSchema() throws IOException {
        try (InputStream stream = getClass().getResourceAsStream("/schema.sql")) {
            assertThat(stream).as("classpath의 schema.sql").isNotNull();
            return new String(stream.readAllBytes(), StandardCharsets.UTF_8);
        }
    }
}
