package com.jdsnack.analysis;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE, properties = "jdsnack.ai.usage.daily-limit=1")
/** H2/Flyway-backed contract tests for the AI usage quota repository and service. */
class AiUsageQuotaRepositoryTest {
    private static final LocalDate USAGE_DATE = LocalDate.of(2026, 9, 16);
    private static final OffsetDateTime RESET_AT = OffsetDateTime.parse("2026-09-17T00:00:00+09:00");
    @Autowired
    private AiUsageQuotaRepository repository;
    @Autowired
    private AiUsageQuotaService service;
    @Autowired
    private JdbcTemplate jdbcTemplate;
    @Test
    void reservesOnceAndRecordsTheLedgerEntry() {
        String userId = createUser();
        String historyId = UUID.randomUUID().toString();
        try {
            AiUsageReservation reservation = reserve(userId, 2, historyId, 123L);
            assertThat(reservation.reserved()).isTrue();
            assertThat(reservation.used()).isEqualTo(1);
            assertThat(reservation.limit()).isEqualTo(2);
            assertThat(reservation.remaining()).isEqualTo(1);
            assertThat(reservation.usageId()).isNotBlank();
            assertThat(count("ai_usage_quota", "used_count", userId)).isEqualTo(1);
            Map<String, Object> ledger = jdbcTemplate.queryForMap("SELECT user_id, usage_date, history_id, endpoint, "
                    + "daily_limit, used_count, status FROM ai_usage_ledger WHERE usage_id = ?", reservation.usageId());
            assertThat(ledger)
                    .containsEntry("USER_ID", userId)
                    .containsEntry("USAGE_DATE", java.sql.Date.valueOf(USAGE_DATE))
                    .containsEntry("HISTORY_ID", historyId)
                    .containsEntry("ENDPOINT", "/api/analysis-histories")
                    .containsEntry("DAILY_LIMIT", 2)
                    .containsEntry("USED_COUNT", 1)
                    .containsEntry("STATUS", "RESERVED");
        } finally {
            deleteUser(userId);
        }
    }
    @Test
    void rejectsReservationAfterTheDailyLimitWithoutIncreasingUsage() {
        String userId = createUser();
        try {
            AiUsageReservation first = reserve(userId, 1);
            AiUsageReservation second = reserve(userId, 1);
            assertThat(first.reserved()).isTrue();
            assertThat(second.reserved()).isFalse();
            assertThat(second.usageId()).isNull();
            assertThat(second.used()).isEqualTo(1);
            assertThat(second.remaining()).isZero();
            assertThat(count("ai_usage_quota", "used_count", userId)).isEqualTo(1);
            assertThat(count("ai_usage_ledger", "COUNT(*)", userId)).isEqualTo(1);
        } finally {
            deleteUser(userId);
        }
    }
    @Test
    void concurrentReservationsForOneUserNeverExceedTheDailyLimit() throws Exception {
        String userId = createUser();
        int dailyLimit = 3;
        int workerCount = 12;
        ExecutorService executor = Executors.newFixedThreadPool(workerCount);
        CountDownLatch ready = new CountDownLatch(workerCount);
        CountDownLatch start = new CountDownLatch(1);
        List<Future<AiUsageReservation>> futures = new ArrayList<>();
        try {
            for (int index = 0; index < workerCount; index++) {
                String historyId = UUID.randomUUID().toString();
                futures.add(executor.submit(() -> {
                    ready.countDown();
                    start.await();
                    return reserve(userId, dailyLimit, historyId);
                }));
            }
            ready.await();
            start.countDown();
            long successfulReservations = 0;
            for (Future<AiUsageReservation> future : futures) {
                if (future.get().reserved()) {
                    successfulReservations++;
                }
            }
            assertThat(successfulReservations).isLessThanOrEqualTo(dailyLimit);
            assertThat(count("ai_usage_quota", "used_count", userId)).isLessThanOrEqualTo(dailyLimit);
            assertThat(count("ai_usage_ledger", "COUNT(*)", userId)).isEqualTo((int) successfulReservations);
        } finally {
            executor.shutdownNow();
            deleteUser(userId);
        }
    }
    @Test
    void serviceThrowsQuotaExceededWithRetryMetadata() {
        String userId = createUser();
        try {
            service.reserve(userId, UUID.randomUUID().toString(), "/api/analysis-histories");
            assertThatThrownBy(() -> service.reserve(userId, UUID.randomUUID().toString(), "/api/analysis-histories"))
                    .isInstanceOf(AiQuotaExceededException.class)
                    .satisfies(throwable -> {
                        AiQuotaExceededException exception = (AiQuotaExceededException) throwable;
                        Map<String, Object> metadata = exception.toDetail().metadata();
                        assertThat(metadata)
                                .containsKeys("retryAfter", "limit", "remaining", "resetAt")
                                .containsEntry("limit", 1)
                                .containsEntry("remaining", 0);
                        assertThat(metadata.get("retryAfter")).isInstanceOf(Long.class);
                        assertThat((Long) metadata.get("retryAfter")).isGreaterThanOrEqualTo(0L);
                        assertThat(metadata.get("resetAt")).isInstanceOf(String.class);
                        assertThat(OffsetDateTime.parse((String) metadata.get("resetAt"))).isNotNull();
                    });
        } finally {
            deleteUser(userId);
        }
    }
    private String createUser() {
        String userId = UUID.randomUUID().toString();
        jdbcTemplate.update("INSERT INTO app_user (user_id, provider, provider_subject, email, display_name, created_at, "
                + "updated_at) VALUES (?, 'google', ?, ?, 'Quota Test User', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
                userId, "quota-subject-" + userId, "quota-" + userId + "@example.com");
        return userId;
    }
    private AiUsageReservation reserve(String userId, int dailyLimit) {
        return reserve(userId, dailyLimit, UUID.randomUUID().toString(), 60L);
    }
    private AiUsageReservation reserve(String userId, int dailyLimit, String historyId) {
        return reserve(userId, dailyLimit, historyId, 60L);
    }
    private AiUsageReservation reserve(String userId, int dailyLimit, String historyId, long retryAfter) {
        return repository.reserve(userId, USAGE_DATE, dailyLimit, historyId,
                "/api/analysis-histories", retryAfter, RESET_AT);
    }
    private int count(String table, String expression, String userId) {
        return jdbcTemplate.queryForObject("SELECT " + expression + " FROM " + table
                + " WHERE user_id = ? AND usage_date = ?", Integer.class, userId, java.sql.Date.valueOf(USAGE_DATE));
    }
    private void deleteUser(String userId) {
        jdbcTemplate.update("DELETE FROM app_user WHERE user_id = ?", userId);
    }
}
