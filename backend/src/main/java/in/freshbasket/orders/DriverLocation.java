package in.freshbasket.orders;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;

@Entity @Table(name="driver_locations")
public class DriverLocation {
    @Id @Column(name="driver_user_id") private Long driverUserId;
    @OneToOne(fetch=FetchType.LAZY,optional=false) @MapsId @JoinColumn(name="driver_user_id") private DriverProfile driver;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="assignment_id",nullable=false) private DriverAssignment assignment;
    @Column(nullable=false,precision=10,scale=7) private BigDecimal latitude;
    @Column(nullable=false,precision=10,scale=7) private BigDecimal longitude;
    @Column(nullable=false) private boolean active=true;
    @Column(name="updated_at",nullable=false) private Instant updatedAt;
    @PrePersist @PreUpdate void updateTime(){updatedAt=Instant.now();}
    protected DriverLocation(){}
    public DriverLocation(DriverProfile driver,DriverAssignment assignment,BigDecimal lat,BigDecimal lon){this.driver=driver;this.assignment=assignment;this.latitude=lat;this.longitude=lon;this.active=true;}
    public Long getDriverUserId(){return driverUserId;} public DriverAssignment getAssignment(){return assignment;} public BigDecimal getLatitude(){return latitude;} public BigDecimal getLongitude(){return longitude;} public boolean isActive(){return active;} public Instant getUpdatedAt(){return updatedAt;}
    public void update(DriverAssignment assignment,BigDecimal lat,BigDecimal lon){this.assignment=assignment;this.latitude=lat;this.longitude=lon;this.active=true;}
    public void stop(){active=false;}
}
