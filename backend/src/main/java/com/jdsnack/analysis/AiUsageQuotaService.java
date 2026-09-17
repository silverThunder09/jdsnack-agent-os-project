package com.jdsnack.analysis;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
@Service
public class AiUsageQuotaService {
    public static final ZoneId SERVICE_ZONE = ZoneId.of("Asia/Seoul");
    private final AiUsageQuotaRepository repository;
    private final int dailyLimit;
    public AiUsageQuotaService(AiUsageQuotaRepository repository, @Value("${jdsnack.ai.usage.daily-limit:20}") int dailyLimit) { this.repository = repository; this.dailyLimit = dailyLimit; }
    @Transactional
    public AiUsageReservation reserve(String userId, String historyId, String endpoint) {
        ZonedDateTime now = ZonedDateTime.now(SERVICE_ZONE);
        ZonedDateTime reset = now.toLocalDate().plusDays(1).atStartOfDay(SERVICE_ZONE);
        long retryAfter = Math.max(0, Duration.between(now, reset).getSeconds());
        AiUsageReservation reservation = repository.reserve(
                userId,
                LocalDate.from(now),
                dailyLimit,
                historyId,
                endpoint,
                retryAfter,
                OffsetDateTime.from(reset)
        );
        if (!reservation.reserved()) {
            throw new AiQuotaExceededException(reservation);
        }
        return reservation;
    }
    public void markRunning(String usageId) { repository.markRunning(usageId); }
    public void markSucceeded(String usageId, AnalysisExecutionVersion diagnosisVersion, AnalysisExecutionVersion matchVersion) {
        repository.markSucceeded(usageId, diagnosisVersion, matchVersion);
    }
    public void markFailed(String usageId, AnalysisExecutionVersion diagnosisVersion, String failureCode) { repository.markFailed(usageId, diagnosisVersion, failureCode); }
}
