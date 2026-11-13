package in.freshbasket.notifications;

import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.*;
import org.springframework.data.domain.*;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

interface DeviceTokenRepository extends JpaRepository<DeviceToken,Long> {
    Optional<DeviceToken> findByToken(String token);
    Optional<DeviceToken> findByUser_IdAndDeviceId(Long userId,String deviceId);
    List<DeviceToken> findByUser_IdAndActiveTrue(Long userId);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select d from DeviceToken d where d.user.id=:user and d.deviceId=:device") Optional<DeviceToken> findLocked(@Param("user") Long userId,@Param("device") String deviceId);
    @Modifying @Query("update DeviceToken d set d.active=false where d.id=:id") void deactivateById(@Param("id") Long id);
}

interface NotificationRepository extends JpaRepository<NotificationRecord,Long> {
    boolean existsByUser_IdAndDeduplicationKey(Long userId,String key);
    Page<NotificationRecord> findByUser_Id(Long userId,Pageable pageable);
    long countByUser_IdAndReadAtIsNull(Long userId);
    @Query("select n.id from NotificationRecord n where ((n.deliveryStatus='PENDING' and n.nextAttemptAt<=:now) or (n.deliveryStatus='SENDING' and n.nextAttemptAt<=:now)) order by n.createdAt asc") List<Long> findDueIds(@Param("now") Instant now,Pageable limit);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select n from NotificationRecord n where n.id=:id") Optional<NotificationRecord> findLocked(@Param("id") Long id);
}
