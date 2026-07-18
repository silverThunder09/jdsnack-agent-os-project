package com.jdsnack.auth;

import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
public class UserService {

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public UserRecord upsertGoogleUser(GoogleUserProfile profile) {
        return userRepository.saveGoogleUser(profile);
    }

    public Optional<UserRecord> findById(String id) {
        return userRepository.findById(id);
    }
}
