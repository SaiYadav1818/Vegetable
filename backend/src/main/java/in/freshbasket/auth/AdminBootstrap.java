package in.freshbasket.auth;

import in.freshbasket.user.AppUser;
import in.freshbasket.user.Role;
import in.freshbasket.user.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class AdminBootstrap {
    @Bean
    @ConditionalOnProperty(name="app.admin-bootstrap.enabled",havingValue="true")
    ApplicationRunner bootstrapAdmin(UserRepository users,PasswordEncoder encoder,
            @Value("${app.admin-bootstrap.email:}") String email,
            @Value("${app.admin-bootstrap.password:}") String password) {
        return args -> {
            if(users.existsByRole(Role.ADMIN)) return;
            if(email.isBlank()||password.length()<12) throw new IllegalStateException(
                    "No ADMIN account exists. Set ADMIN_BOOTSTRAP_ENABLED=true with ADMIN_BOOTSTRAP_EMAIL and a 12+ character ADMIN_BOOTSTRAP_PASSWORD for first-run setup.");
            String normalized=email.trim().toLowerCase();
            if(users.existsByEmail(normalized)) throw new IllegalStateException("Bootstrap email already belongs to another account");
            users.save(new AppUser(normalized,encoder.encode(password),"FreshBasket Admin",null,Role.ADMIN));
        };
    }
}
