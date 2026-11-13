package in.freshbasket.auth;

import in.freshbasket.security.JwtService;
import in.freshbasket.user.AppUser;
import in.freshbasket.user.Role;
import in.freshbasket.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.server.ResponseStatusException;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class AuthServiceTest {
    private final UserRepository users = mock(UserRepository.class);
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
    private final JwtService jwt = new JwtService("test-secret-that-is-definitely-32-bytes-long", 60);
    private final AuthService service = new AuthService(users, encoder, jwt, mock(AuthenticationManager.class));

    @Test void registrationCreatesCustomerWithHashedPasswordAndJwt() {
        when(users.existsByEmail("asha@example.com")).thenReturn(false);
        when(users.save(any(AppUser.class))).thenAnswer(call -> {
            AppUser user = call.getArgument(0);
            org.springframework.test.util.ReflectionTestUtils.setField(user, "id", 1L);
            return user;
        });

        var result = service.register(new AuthDtos.RegisterRequest("Asha Rao", "Asha@Example.com", "good-password", null));

        var stored = org.mockito.ArgumentCaptor.forClass(AppUser.class);
        verify(users).save(stored.capture());
        assertEquals(Role.CUSTOMER, stored.getValue().getRole());
        assertNotEquals("good-password", stored.getValue().getPasswordHash());
        assertTrue(encoder.matches("good-password", stored.getValue().getPasswordHash()));
        assertEquals("asha@example.com", result.email());
        assertEquals(Role.CUSTOMER, result.role());
        assertEquals("asha@example.com", jwt.subject(result.accessToken()));
    }

    @Test void registrationRejectsDuplicateEmail() {
        when(users.existsByEmail("asha@example.com")).thenReturn(true);
        assertThrows(ResponseStatusException.class, () -> service.register(
                new AuthDtos.RegisterRequest("Asha Rao", "asha@example.com", "good-password", null)));
        verify(users, never()).save(any());
    }
}
