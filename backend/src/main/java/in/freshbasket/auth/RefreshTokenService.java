package in.freshbasket.auth;

import in.freshbasket.security.JwtService;
import in.freshbasket.user.AppUser;
import in.freshbasket.user.UserRepository;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class RefreshTokenService {
    private static final Logger log = LoggerFactory.getLogger(RefreshTokenService.class);
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final long REFRESH_EXPIRATION_SECONDS = 30L * 24 * 60 * 60; // 30 days

    private final RefreshTokenRepository refreshTokens;
    private final UserRepository users;
    private final JwtService jwt;

    public RefreshTokenService(RefreshTokenRepository refreshTokens, UserRepository users, JwtService jwt) {
        this.refreshTokens = refreshTokens;
        this.users = users;
        this.jwt = jwt;
    }

    @Transactional
    public String createRefreshToken(AppUser user) {
        String rawToken = generateRawToken();
        String hash = hash(rawToken);
        Instant expiresAt = Instant.now().plusSeconds(REFRESH_EXPIRATION_SECONDS);
        refreshTokens.save(new RefreshToken(user, hash, expiresAt));
        return rawToken;
    }

    @Transactional
    public AuthDtos.AuthResponse rotate(String rawToken) {
        if (rawToken == null || rawToken.isBlank()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Refresh token is required");
        }
        String currentHash = hash(rawToken.trim());
        RefreshToken existing = refreshTokens.findByTokenHash(currentHash)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid refresh token"));

        AppUser user = existing.getUser();
        if (!user.isActive()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Account is disabled");
        }

        // Token reuse detection: if a revoked token is presented, revoke all sessions for security
        if (existing.isRevoked()) {
            log.warn("Refresh token reuse detected for userId={}. Revoking all active tokens.", user.getId());
            revokeAllForUser(user.getId());
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Session expired or invalid. Please log in again.");
        }

        if (existing.getExpiresAt().isBefore(Instant.now())) {
            existing.revoke(null);
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Refresh token expired. Please log in again.");
        }

        // Generate replacement token
        String newRawToken = generateRawToken();
        String newHash = hash(newRawToken);
        Instant newExpiry = Instant.now().plusSeconds(REFRESH_EXPIRATION_SECONDS);

        existing.revoke(newHash);
        refreshTokens.save(new RefreshToken(user, newHash, newExpiry));

        String newAccessToken = jwt.issue(user);
        return new AuthDtos.AuthResponse(newAccessToken, "Bearer", user.getId(), user.getEmail(), user.getFullName(), user.getRole(), newRawToken);
    }

    @Transactional
    public void revoke(String rawToken) {
        if (rawToken == null || rawToken.isBlank()) return;
        String hash = hash(rawToken.trim());
        refreshTokens.findByTokenHash(hash).ifPresent(t -> t.revoke(null));
    }

    @Transactional
    public void revokeAllForUser(Long userId) {
        List<RefreshToken> active = refreshTokens.findByUser_IdAndRevokedFalse(userId);
        for (RefreshToken token : active) {
            token.revoke(null);
        }
    }

    private static String generateRawToken() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    public static String hash(String rawToken) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] encoded = digest.digest(rawToken.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(64);
            for (byte b : encoded) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 algorithm not available", e);
        }
    }
}
