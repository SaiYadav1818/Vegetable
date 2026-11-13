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
    private final UserRepository users; private final PasswordEncoder encoder; private final JwtService jwt; private final AuthenticationManager authenticationManager;
    public AuthService(UserRepository users, PasswordEncoder encoder, JwtService jwt, AuthenticationManager authenticationManager){this.users=users;this.encoder=encoder;this.jwt=jwt;this.authenticationManager=authenticationManager;}
    public AuthDtos.AuthResponse register(AuthDtos.RegisterRequest request) {
        String email=request.email().trim().toLowerCase();
        if(users.existsByEmail(email)) throw new ResponseStatusException(HttpStatus.CONFLICT,"Email is already registered");
        if(request.phoneNumber()!=null && !request.phoneNumber().isBlank() && users.existsByPhoneNumber(request.phoneNumber())) throw new ResponseStatusException(HttpStatus.CONFLICT,"Phone number is already registered");
        AppUser user=users.save(new AppUser(email,encoder.encode(request.password()),request.fullName().trim(),blankToNull(request.phoneNumber()),Role.CUSTOMER));
        return response(user);
    }
    public AuthDtos.AuthResponse login(AuthDtos.LoginRequest request) {
        String email=request.email().trim().toLowerCase();
        try { authenticationManager.authenticate(new UsernamePasswordAuthenticationToken(email,request.password())); }
        catch(AuthenticationException ex){throw new ResponseStatusException(HttpStatus.UNAUTHORIZED,"Invalid email or password");}
        return response(users.findByEmail(email).filter(AppUser::isActive).orElseThrow(()->new ResponseStatusException(HttpStatus.UNAUTHORIZED,"Account is unavailable")));
    }
    private AuthDtos.AuthResponse response(AppUser u){return new AuthDtos.AuthResponse(jwt.issue(u),"Bearer",u.getId(),u.getEmail(),u.getFullName(),u.getRole());}
    private String blankToNull(String s){return s==null||s.isBlank()?null:s.trim();}
}
