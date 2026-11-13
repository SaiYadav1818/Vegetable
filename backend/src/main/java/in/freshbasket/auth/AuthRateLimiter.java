package in.freshbasket.auth;

import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

@Component
public class AuthRateLimiter {
    private static final int MAX_LOGIN_ATTEMPTS = 5;
    private static final long LOGIN_BLOCK_DURATION_SECONDS = 60;
    private static final int MAX_REGISTER_ATTEMPTS = 10;
    private static final long REGISTER_WINDOW_SECONDS = 600;

    private final Map<String, AttemptTracker> loginAttempts = new ConcurrentHashMap<>();
    private final Map<String, AttemptTracker> registerAttempts = new ConcurrentHashMap<>();

    public void checkLoginAllowed(String ip, String email) {
        cleanOldTrackers();
        String key = (ip + ":" + (email == null ? "" : email.trim().toLowerCase()));
        AttemptTracker tracker = loginAttempts.get(key);
        if (tracker != null && tracker.isBlocked(MAX_LOGIN_ATTEMPTS, LOGIN_BLOCK_DURATION_SECONDS)) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,
                    "Too many failed login attempts. Please wait " + tracker.remainingSeconds(LOGIN_BLOCK_DURATION_SECONDS) + " seconds before trying again.");
        }
    }

    public void recordLoginFailure(String ip, String email) {
        String key = (ip + ":" + (email == null ? "" : email.trim().toLowerCase()));
        loginAttempts.compute(key, (k, existing) -> {
            if (existing == null || existing.isExpired(LOGIN_BLOCK_DURATION_SECONDS)) {
                return new AttemptTracker(1, Instant.now());
            }
            return new AttemptTracker(existing.count + 1, Instant.now());
        });
    }

    public void recordLoginSuccess(String ip, String email) {
        String key = (ip + ":" + (email == null ? "" : email.trim().toLowerCase()));
        loginAttempts.remove(key);
    }

    public void checkRegisterAllowed(String ip) {
        cleanOldTrackers();
        String key = (ip == null ? "unknown" : ip.trim());
        AttemptTracker tracker = registerAttempts.get(key);
        if (tracker != null && tracker.isBlocked(MAX_REGISTER_ATTEMPTS, REGISTER_WINDOW_SECONDS)) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,
                    "Too many registration attempts. Please wait " + tracker.remainingSeconds(REGISTER_WINDOW_SECONDS) + " seconds before trying again.");
        }
    }

    public void recordRegisterAttempt(String ip) {
        String key = (ip == null ? "unknown" : ip.trim());
        registerAttempts.compute(key, (k, existing) -> {
            if (existing == null || existing.isExpired(REGISTER_WINDOW_SECONDS)) {
                return new AttemptTracker(1, Instant.now());
            }
            return new AttemptTracker(existing.count + 1, existing.firstAttempt);
        });
    }

    public void resetForTests() {
        loginAttempts.clear();
        registerAttempts.clear();
    }

    private void cleanOldTrackers() {
        if (loginAttempts.size() > 5000) {
            loginAttempts.entrySet().removeIf(e -> e.getValue().isExpired(LOGIN_BLOCK_DURATION_SECONDS * 2));
        }
        if (registerAttempts.size() > 5000) {
            registerAttempts.entrySet().removeIf(e -> e.getValue().isExpired(REGISTER_WINDOW_SECONDS * 2));
        }
    }

    private static class AttemptTracker {
        private final int count;
        private final Instant firstAttempt;

        AttemptTracker(int count, Instant firstAttempt) {
            this.count = count;
            this.firstAttempt = firstAttempt;
        }

        boolean isBlocked(int maxAllowed, long windowSeconds) {
            if (count >= maxAllowed) {
                return !isExpired(windowSeconds);
            }
            return false;
        }

        boolean isExpired(long windowSeconds) {
            return Instant.now().isAfter(firstAttempt.plusSeconds(windowSeconds));
        }

        long remainingSeconds(long windowSeconds) {
            long remaining = (firstAttempt.getEpochSecond() + windowSeconds) - Instant.now().getEpochSecond();
            return Math.max(1, remaining);
        }
    }
}
