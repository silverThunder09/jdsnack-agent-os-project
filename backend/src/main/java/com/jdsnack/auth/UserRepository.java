package com.jdsnack.auth;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.dao.DuplicateKeyException;
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
        int updated = updateGoogleUser(profile);
        if (updated == 0) {
            insertGoogleUserOrRecoverRace(profile);
        }

        return findByProviderSubject(profile.providerSubject()).orElseThrow();
    }

    private int updateGoogleUser(GoogleUserProfile profile) {
        return jdbcTemplate.update(
                "UPDATE app_user SET email = ?, display_name = ?, updated_at = CURRENT_TIMESTAMP "
                        + "WHERE provider = 'google' AND provider_subject = ?",
                profile.email(),
                profile.displayName(),
                profile.providerSubject()
        );
    }

    private void insertGoogleUserOrRecoverRace(GoogleUserProfile profile) {
        String id = UUID.randomUUID().toString();
        try {
            jdbcTemplate.update(
                    "INSERT INTO app_user (user_id, provider, provider_subject, email, display_name, created_at, updated_at) "
                            + "VALUES (?, 'google', ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
                    id,
                    profile.providerSubject(),
                    profile.email(),
                    profile.displayName()
            );
        } catch (DuplicateKeyException exception) {
            updateGoogleUser(profile);
        }
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
