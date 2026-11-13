package in.freshbasket.orders;

import in.freshbasket.user.AppUser;
import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="drivers")
public class DriverProfile {
    @Id @Column(name="user_id") private Long userId;
    @MapsId @OneToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="user_id") private AppUser user;
    @Column(nullable=false) private boolean online;
    @Column(nullable=false) private boolean available=true;
    @Column(name="created_at",nullable=false,updatable=false) private Instant createdAt;
    @Column(name="updated_at",nullable=false) private Instant updatedAt;
    @PrePersist void create(){createdAt=updatedAt=Instant.now();} @PreUpdate void update(){updatedAt=Instant.now();}
    protected DriverProfile(){} public DriverProfile(AppUser user){this.user=user;}
    public Long getUserId(){return userId;} public AppUser getUser(){return user;} public boolean isOnline(){return online;} public boolean isAvailable(){return available;}
    public void setOnline(boolean online){this.online=online;if(!online)available=false;}
    public void setAvailable(boolean available){this.available=available;}
}
