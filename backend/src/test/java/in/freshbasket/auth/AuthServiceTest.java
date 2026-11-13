package in.freshbasket.auth;

import in.freshbasket.security.JwtService;
import in.freshbasket.user.AppUser;
import in.freshbasket.user.Role;
import in.freshbasket.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.server.ResponseStatusException;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class AuthServiceTest {
    private final UserRepository users = mock(UserRepository.class);
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
    private final JwtService jwt = new JwtService("test-secret-that-is-definitely-32-bytes-long", 60);
    private final RefreshTokenService refreshTokenService = mock(RefreshTokenService.class);
    private final AuthRateLimiter rateLimiter = new AuthRateLimiter();
    private final AuthenticationManager authManager = mock(AuthenticationManager.class);
    private AuthService service;

    @BeforeEach
    void setUp() {
        rateLimiter.resetForTests();
        service = new AuthService(users, encoder, jwt, authManager, refreshTokenService, rateLimiter);
        when(refreshTokenService.createRefreshToken(any())).thenReturn("sample-refresh-token");
    }

    @Test
    void registrationCreatesCustomerWithHashedPasswordAndTokens() {
        when(users.existsByEmail("asha@example.com")).thenReturn(false);
        when(users.save(any(AppUser.class))).thenAnswer(call -> {
            AppUser user = call.getArgument(0);
            org.springframework.test.util.ReflectionTestUtils.setField(user, "id", 1L);
            return user;
        });

        var result = service.register(new AuthDtos.RegisterRequest("Asha Rao", "Asha@Example.com", "good-password", null), "127.0.0.1");

        var stored = org.mockito.ArgumentCaptor.forClass(AppUser.class);
        verify(users).save(stored.capture());
        assertEquals(Role.CUSTOMER, stored.getValue().getRole());
        assertNotEquals("good-password", stored.getValue().getPasswordHash());
        assertTrue(encoder.matches("good-password", stored.getValue().getPasswordHash()));
        assertEquals("asha@example.com", result.email());
        assertEquals(Role.CUSTOMER, result.role());
        assertEquals("asha@example.com", jwt.subject(result.accessToken()));
        assertEquals("sample-refresh-token", result.refreshToken());
    }

    @Test
    void registrationRejectsDuplicateEmailWithoutEnumeration() {
        when(users.existsByEmail("asha@example.com")).thenReturn(true);
        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () -> service.register(
                new AuthDtos.RegisterRequest("Asha Rao", "asha@example.com", "good-password", null), "127.0.0.1"));
        assertEquals(409, ex.getStatusCode().value());
        verify(users, never()).save(any());
    }

    @Test
    void rateLimiterBlocksAfterFiveFailedLoginAttempts() {
        when(authManager.authenticate(any())).thenThrow(new BadCredentialsException("Bad credentials"));
        var loginReq = new AuthDtos.LoginRequest("target@example.com", "wrong-password");

        for (int i = 0; i < 5; i++) {
            ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                    () -> service.login(loginReq, "192.168.1.10"));
            assertEquals(401, ex.getStatusCode().value());
        }

        // 6th attempt should be blocked by rate limiter with 429 Too Many Requests
        ResponseStatusException blocked = assertThrows(ResponseStatusException.class,
                () -> service.login(loginReq, "192.168.1.10"));
        assertEquals(429, blocked.getStatusCode().value());
        assertTrue(blocked.getReason().contains("Too many failed login attempts"));
    }
}
