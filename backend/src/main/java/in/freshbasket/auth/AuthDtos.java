package in.freshbasket.auth;

import jakarta.validation.constraints.*;
import in.freshbasket.user.Role;

public final class AuthDtos {
    private AuthDtos() {}
    public record RegisterRequest(@NotBlank @Size(max=120) String fullName, @NotBlank @Email @Size(max=254) String email,
            @NotBlank @Size(min=8,max=72) String password, @Pattern(regexp="^$|^[0-9+() -]{7,20}$") String phoneNumber) {}
    public record LoginRequest(@NotBlank @Email String email, @NotBlank String password) {}
    public record AuthResponse(String accessToken, String tokenType, long userId, String email, String fullName, Role role) {}
}
