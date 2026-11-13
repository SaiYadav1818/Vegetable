package in.freshbasket.auth;

import in.freshbasket.security.JwtService;
import in.freshbasket.user.*;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AuthService {
    private final UserRepository users;
    private final PasswordEncoder encoder;
    private final JwtService jwt;
    private final AuthenticationManager authenticationManager;
    private final RefreshTokenService refreshTokenService;
    private final AuthRateLimiter rateLimiter;

    public AuthService(UserRepository users, PasswordEncoder encoder, JwtService jwt,
            AuthenticationManager authenticationManager, RefreshTokenService refreshTokenService,
            AuthRateLimiter rateLimiter) {
        this.users = users;
        this.encoder = encoder;
        this.jwt = jwt;
        this.authenticationManager = authenticationManager;
        this.refreshTokenService = refreshTokenService;
        this.rateLimiter = rateLimiter;
    }

    public AuthDtos.AuthResponse register(AuthDtos.RegisterRequest request, String clientIp) {
        if (clientIp != null) {
            rateLimiter.checkRegisterAllowed(clientIp);
            rateLimiter.recordRegisterAttempt(clientIp);
        }
        String email = request.email().trim().toLowerCase();
        if (users.existsByEmail(email)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Unable to register with the provided credentials. If you already have an account, please sign in.");
        }
        if (request.phoneNumber() != null && !request.phoneNumber().isBlank() && users.existsByPhoneNumber(request.phoneNumber())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Unable to register with the provided credentials. If you already have an account, please sign in.");
        }
        AppUser user = users.save(new AppUser(email, encoder.encode(request.password()), request.fullName().trim(), blankToNull(request.phoneNumber()), Role.CUSTOMER));
        return response(user);
    }

    public AuthDtos.AuthResponse login(AuthDtos.LoginRequest request, String clientIp) {
        String email = request.email().trim().toLowerCase();
        if (clientIp != null) {
            rateLimiter.checkLoginAllowed(clientIp, email);
        }
        try {
            authenticationManager.authenticate(new UsernamePasswordAuthenticationToken(email, request.password()));
        } catch (AuthenticationException ex) {
            if (clientIp != null) rateLimiter.recordLoginFailure(clientIp, email);
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid email or password");
        }
        AppUser user = users.findByEmail(email).filter(AppUser::isActive).orElse(null);
        if (user == null) {
            if (clientIp != null) rateLimiter.recordLoginFailure(clientIp, email);
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid email or password");
        }
        if (clientIp != null) rateLimiter.recordLoginSuccess(clientIp, email);
        return response(user);
    }

    public AuthDtos.AuthResponse refresh(AuthDtos.RefreshRequest request) {
        return refreshTokenService.rotate(request.refreshToken());
    }

    public void logout(AuthDtos.RefreshRequest request) {
        refreshTokenService.revoke(request.refreshToken());
    }

    private AuthDtos.AuthResponse response(AppUser u) {
        String accessToken = jwt.issue(u);
        String refreshToken = refreshTokenService.createRefreshToken(u);
        return new AuthDtos.AuthResponse(accessToken, "Bearer", u.getId(), u.getEmail(), u.getFullName(), u.getRole(), refreshToken);
    }

    private String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
