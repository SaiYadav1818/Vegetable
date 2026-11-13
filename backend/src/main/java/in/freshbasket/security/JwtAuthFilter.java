package in.freshbasket.security;

import in.freshbasket.user.UserRepository;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class JwtAuthFilter extends OncePerRequestFilter {
    private final JwtService jwt; private final UserRepository users;
    public JwtAuthFilter(JwtService jwt, UserRepository users){this.jwt=jwt;this.users=users;}
    @Override protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain) throws ServletException, IOException {
        String header=req.getHeader("Authorization");
        if(header!=null && header.startsWith("Bearer ")) try {
            var user=users.findByEmail(jwt.subject(header.substring(7))).filter(u->u.isActive());
            user.ifPresent(u->SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                    u.getEmail(), null, java.util.List.of(new SimpleGrantedAuthority("ROLE_"+u.getRole().name())))));
        } catch(JwtException | IllegalArgumentException ignored) { SecurityContextHolder.clearContext(); }
        chain.doFilter(req,res);
    }
}
