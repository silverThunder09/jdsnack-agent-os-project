package com.jdsnack.auth;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public class UserRepository {

    private final JdbcTemplate jdbcTemplate;

    public UserRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public UserRecord saveGoogleUser(GoogleUserProfile profile) {
        Optional<UserRecord> existing = findByProviderSubject(profile.providerSubject());
        if (existing.isPresent()) {
            jdbcTemplate.update(
                    "UPDATE app_user SET email = ?, display_name = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ?",
                    profile.email(),
                    profile.displayName(),
                    existing.get().id()
            );
            return findById(existing.get().id()).orElseThrow();
        }

        String id = UUID.randomUUID().toString();
        jdbcTemplate.update(
                "INSERT INTO app_user (user_id, provider, provider_subject, email, display_name, created_at, updated_at) "
                        + "VALUES (?, 'google', ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
                id,
                profile.providerSubject(),
                profile.email(),
                profile.displayName()
        );
        return findById(id).orElseThrow();
    }

    public Optional<UserRecord> findById(String id) {
        return jdbcTemplate.query(
                "SELECT user_id, provider, provider_subject, email, display_name FROM app_user WHERE user_id = ?",
                (resultSet, rowNum) -> new UserRecord(
                        resultSet.getString("user_id"),
                        resultSet.getString("provider"),
                        resultSet.getString("provider_subject"),
                        resultSet.getString("email"),
                        resultSet.getString("display_name")
                ),
                id
        ).stream().findFirst();
    }

    private Optional<UserRecord> findByProviderSubject(String providerSubject) {
        return jdbcTemplate.query(
                "SELECT user_id, provider, provider_subject, email, display_name FROM app_user "
                        + "WHERE provider = 'google' AND provider_subject = ?",
                (resultSet, rowNum) -> new UserRecord(
                        resultSet.getString("user_id"),
                        resultSet.getString("provider"),
                        resultSet.getString("provider_subject"),
                        resultSet.getString("email"),
                        resultSet.getString("display_name")
                ),
                providerSubject
        ).stream().findFirst();
    }
}
