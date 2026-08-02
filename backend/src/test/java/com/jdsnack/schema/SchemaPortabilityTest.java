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
 * 동작해야 한다고 규정한다. 그러나 로컬·테스트가 H2만 사용하기 때문에 PostgreSQL에 없는 문법이
 * 들어와도 어떤 게이트에도 걸리지 않았다(Issue #175, 회귀 커밋 #144).
 *
 * <p>이 테스트는 그 빈 구멍을 막는다. 초기화 스크립트가 한쪽 DBMS에서만 통하는 문법을 쓰면 실패한다.
 *
 * <p>정규식 기반이라 열거한 패턴만 잡는다. 실제 PostgreSQL에 스크립트를 올려보는 검증이
 * 상위 방어선이며, 이 테스트는 그보다 빠르게 도는 1차 가드다.
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

    /** 한쪽 DBMS에서만 통하는 upsert 문법 → 대체 방법. */
    private static final Map<String, String> DIALECT_ONLY_UPSERTS = new LinkedHashMap<>(Map.of(
            ") KEY (", "H2 전용 MERGE 문법입니다. PostgreSQL의 MERGE는 USING ... ON ... WHEN MATCHED 형태라 받지 않습니다.",
            "ON CONFLICT", "PostgreSQL 전용입니다. H2가 거부합니다(ScriptStatementFailedException).",
            "ON DUPLICATE KEY", "MySQL 전용입니다.",
            "INSERT OR REPLACE", "SQLite 전용입니다."
    ));

    private static final String[] INIT_SCRIPTS = {"/schema.sql", "/data.sql"};

    @Test
    void initScriptsUseOnlyTypesAvailableInBothPostgresAndH2() throws IOException {
        for (String script : INIT_SCRIPTS) {
            String sql = read(script);

            for (Map.Entry<String, String> entry : UNSUPPORTED_BY_POSTGRES.entrySet()) {
                String unsupported = entry.getKey();
                Matcher matcher = Pattern
                        .compile("\\b" + unsupported + "\\b", Pattern.CASE_INSENSITIVE)
                        .matcher(sql);

                assertThat(matcher.find())
                        .withFailMessage(
                                "%s가 PostgreSQL에 없는 타입 '%s'을(를) 사용합니다. '%s'로 바꾸세요. "
                                        + "H2는 '%s'을(를) 받아주지만 PostgreSQL에서는 실행이 실패합니다. "
                                        + "근거: ADR-019, Issue #175.",
                                script, unsupported, entry.getValue(), unsupported)
                        .isFalse();
            }
        }
    }

    @Test
    void initScriptsAvoidDialectOnlyUpsertSyntax() throws IOException {
        for (String script : INIT_SCRIPTS) {
            String sql = read(script);

            for (Map.Entry<String, String> entry : DIALECT_ONLY_UPSERTS.entrySet()) {
                String syntax = entry.getKey();

                assertThat(sql.toUpperCase().contains(syntax.toUpperCase()))
                        .withFailMessage(
                                "%s가 '%s' 문법을 사용합니다. %s "
                                        + "두 DBMS가 모두 지원하는 표준 SQL(예: DELETE 후 INSERT)을 쓰세요. "
                                        + "근거: ADR-019, Issue #175.",
                                script, syntax, entry.getValue())
                        .isFalse();
            }
        }
    }

    /**
     * 주석은 검사 대상에서 뺀다. 주석에는 "이 문법은 쓰지 말 것" 같은 설명이 들어가므로,
     * 원문 그대로 훑으면 설명 문장이 위반으로 잡히는 오탐이 난다.
     */
    private String read(String script) throws IOException {
        try (InputStream stream = getClass().getResourceAsStream(script)) {
            assertThat(stream).as("classpath의 %s", script).isNotNull();
            String raw = new String(stream.readAllBytes(), StandardCharsets.UTF_8);
            return raw
                    .replaceAll("(?s)/\\*.*?\\*/", " ")
                    .replaceAll("(?m)--.*$", " ");
        }
    }
}
