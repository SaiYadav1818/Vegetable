package in.freshbasket.auth;

import in.freshbasket.security.JwtService;
import in.freshbasket.user.AppUser;
import in.freshbasket.user.Role;
import in.freshbasket.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class RefreshTokenServiceTest {
    private final RefreshTokenRepository tokens = mock(RefreshTokenRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final JwtService jwt = new JwtService("test-secret-that-is-definitely-32-bytes-long", 15);
    private RefreshTokenService service;
    private AppUser testUser;

    @BeforeEach
    void setUp() {
        service = new RefreshTokenService(tokens, users, jwt);
        testUser = new AppUser("user@example.com", "hash", "John Doe", "9876543210", Role.CUSTOMER);
        ReflectionTestUtils.setField(testUser, "id", 10L);
    }

    @Test
    void createRefreshTokenSavesHashedToken() {
        when(tokens.save(any(RefreshToken.class))).thenAnswer(i -> i.getArgument(0));

        String rawToken = service.createRefreshToken(testUser);
        assertNotNull(rawToken);
        assertFalse(rawToken.isBlank());

        var captor = org.mockito.ArgumentCaptor.forClass(RefreshToken.class);
        verify(tokens).save(captor.capture());
        assertEquals(RefreshTokenService.hash(rawToken), captor.getValue().getTokenHash());
        assertFalse(captor.getValue().isRevoked());
        assertTrue(captor.getValue().getExpiresAt().isAfter(Instant.now()));
    }

    @Test
    void rotateRevokesOldTokenAndIssuesNewOne() {
        String oldRawToken = "valid-raw-refresh-token";
        String oldHash = RefreshTokenService.hash(oldRawToken);
        RefreshToken stored = new RefreshToken(testUser, oldHash, Instant.now().plusSeconds(3600));

        when(tokens.findByTokenHash(oldHash)).thenReturn(Optional.of(stored));
        when(tokens.save(any(RefreshToken.class))).thenAnswer(i -> i.getArgument(0));

        var response = service.rotate(oldRawToken);

        assertNotNull(response);
        assertNotNull(response.accessToken());
        assertNotNull(response.refreshToken());
        assertNotEquals(oldRawToken, response.refreshToken());
        assertTrue(stored.isRevoked());
        assertEquals(RefreshTokenService.hash(response.refreshToken()), stored.getReplacedByHash());
    }

    @Test
    void rotateRevokedTokenTriggersReuseDetectionAndRevokesAll() {
        String reusedRawToken = "reused-raw-token";
        String hash = RefreshTokenService.hash(reusedRawToken);
        RefreshToken stored = new RefreshToken(testUser, hash, Instant.now().plusSeconds(3600));
        stored.revoke("some-other-hash");

        when(tokens.findByTokenHash(hash)).thenReturn(Optional.of(stored));
        when(tokens.findByUser_IdAndRevokedFalse(10L)).thenReturn(java.util.List.of());

        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () -> service.rotate(reusedRawToken));
        assertEquals(401, ex.getStatusCode().value());
        assertTrue(ex.getReason().contains("Session expired or invalid"));
        verify(tokens).findByUser_IdAndRevokedFalse(10L);
    }
}
