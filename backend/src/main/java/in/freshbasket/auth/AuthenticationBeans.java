package in.freshbasket.auth;

import in.freshbasket.user.UserRepository;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class AuthenticationBeans {
    @Bean UserDetailsService userDetailsService(UserRepository users) {
        return email -> users.findByEmail(email).filter(u->u.isActive()).map(u->User.withUsername(u.getEmail()).password(u.getPasswordHash()).roles(u.getRole().name()).build())
                .orElseThrow(()->new org.springframework.security.core.userdetails.UsernameNotFoundException("Account not found"));
    }
    @Bean DaoAuthenticationProvider authenticationProvider(UserDetailsService service, PasswordEncoder encoder) {
        DaoAuthenticationProvider provider=new DaoAuthenticationProvider(); provider.setUserDetailsService(service); provider.setPasswordEncoder(encoder); return provider;
    }
    @Bean AuthenticationManager authenticationManager(AuthenticationConfiguration configuration) throws Exception{return configuration.getAuthenticationManager();}
}
