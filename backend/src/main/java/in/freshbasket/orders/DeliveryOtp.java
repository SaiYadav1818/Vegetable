package in.freshbasket.orders;

import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="delivery_otp")
public class DeliveryOtp {
    @Id @Column(name="order_id") private Long orderId;
    @OneToOne(fetch=FetchType.LAZY,optional=false) @MapsId @JoinColumn(name="order_id") private CustomerOrder order;
    @Column(name="code_hash",nullable=false,length=100) private String codeHash;
    @Column(name="expires_at",nullable=false) private Instant expiresAt;
    @Column(name="verified_at") private Instant verifiedAt;
    @Column(name="failed_attempts",nullable=false) private short failedAttempts;
    protected DeliveryOtp(){}
    public DeliveryOtp(CustomerOrder order,String hash,Instant expiresAt){this.order=order;this.codeHash=hash;this.expiresAt=expiresAt;}
    public boolean isExpired(){return Instant.now().isAfter(expiresAt);} public boolean isVerified(){return verifiedAt!=null;}
    public boolean matches(String raw,org.springframework.security.crypto.password.PasswordEncoder encoder){return encoder.matches(raw,codeHash);}
    public void failed(){failedAttempts++;} public short getFailedAttempts(){return failedAttempts;} public void verify(){verifiedAt=Instant.now();}
    public void rotate(String newHash,Instant expiry){codeHash=newHash;expiresAt=expiry;failedAttempts=0;verifiedAt=null;}
}
