package in.freshbasket.notifications;

import in.freshbasket.user.AppUser;
import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name="device_tokens", uniqueConstraints={@UniqueConstraint(name="uq_device_tokens_user_device", columnNames={"user_id","device_id"})})
public class DeviceToken {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY, optional=false) @JoinColumn(name="user_id", nullable=false) private AppUser user;
    @Column(name="device_id", nullable=false, length=128) private String deviceId;
    @Column(nullable=false, unique=true, length=512) private String token;
    @Enumerated(EnumType.STRING) @Column(name="device_platform", nullable=false, length=16) private DevicePlatform platform;
    @Column(nullable=false) private boolean active=true;
    @Column(name="created_at", nullable=false, updatable=false) private Instant createdAt;
    @Column(name="updated_at", nullable=false) private Instant updatedAt;
    @PrePersist void create(){createdAt=updatedAt=Instant.now();}
    @PreUpdate void update(){updatedAt=Instant.now();}
    protected DeviceToken(){}
    public DeviceToken(AppUser user,String deviceId,String token,DevicePlatform platform){this.user=user;this.deviceId=deviceId;this.token=token;this.platform=platform;this.active=true;}
    public Long getId(){return id;} public Long getUserId(){return user.getId();} public String getDeviceId(){return deviceId;} public String getToken(){return token;} public boolean isActive(){return active;}
    public void update(AppUser owner,String token,DevicePlatform platform){this.user=owner;this.token=token;this.platform=platform;this.active=true;}
    public void deactivate(){active=false;}
}
