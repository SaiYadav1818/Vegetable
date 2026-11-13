package in.freshbasket.user;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "users")
public class AppUser {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(nullable = false, unique = true, length = 254) private String email;
    @Column(name = "password_hash", nullable = false, length = 100) private String passwordHash;
    @Column(name = "full_name", nullable = false, length = 120) private String fullName;
    @Column(name = "phone_number", unique = true, length = 20) private String phoneNumber;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20) private Role role;
    @Column(nullable = false) private boolean active = true;
    @Column(name = "created_at", nullable = false, updatable = false) private Instant createdAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;
    @PrePersist void onCreate() { createdAt = updatedAt = Instant.now(); }
    @PreUpdate void onUpdate() { updatedAt = Instant.now(); }
    protected AppUser() {}
    public AppUser(String email, String passwordHash, String fullName, String phoneNumber, Role role) {
        this.email=email; this.passwordHash=passwordHash; this.fullName=fullName; this.phoneNumber=phoneNumber; this.role=role;
    }
    public Long getId(){return id;} public String getEmail(){return email;} public String getPasswordHash(){return passwordHash;}
    public String getFullName(){return fullName;} public String getPhoneNumber(){return phoneNumber;} public Role getRole(){return role;}
    public boolean isActive(){return active;}
}
