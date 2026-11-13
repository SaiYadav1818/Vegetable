package in.freshbasket.auth;

import java.util.*;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken,Long>{
    Optional<RefreshToken> findByTokenHash(String tokenHash);
    List<RefreshToken> findByUser_IdAndRevokedFalse(Long userId);
}
