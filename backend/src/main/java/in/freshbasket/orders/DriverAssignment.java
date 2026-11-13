package in.freshbasket.orders;

import in.freshbasket.user.AppUser;
import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="driver_assignments",indexes={
    @Index(name="idx_driver_assignments_driver_status",columnList="driver_user_id,status"),
    @Index(name="idx_driver_assignments_order",columnList="order_id")
})
public class DriverAssignment {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="order_id",nullable=false) private CustomerOrder order;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="driver_user_id",nullable=false) private DriverProfile driver;
    @Enumerated(EnumType.STRING) @Column(nullable=false,length=20) private AssignmentStatus status;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="assigned_by_user_id",nullable=false) private AppUser assignedBy;
    @Column(name="assigned_at",nullable=false,updatable=false) private Instant assignedAt;
    @Column(name="accepted_at") private Instant acceptedAt;
    @Column(name="picked_up_at") private Instant pickedUpAt;
    @Column(name="delivered_at") private Instant deliveredAt;
    @Column(name="failed_at") private Instant failedAt;
    @Column(name="failure_reason",length=300) private String failureReason;
    @PrePersist void create(){assignedAt=Instant.now();}
    protected DriverAssignment(){}
    public DriverAssignment(CustomerOrder order,DriverProfile driver,AppUser admin){this.order=order;this.driver=driver;this.assignedBy=admin;this.status=AssignmentStatus.ASSIGNED;}
    public Long getId(){return id;} public CustomerOrder getOrder(){return order;} public DriverProfile getDriver(){return driver;} public AssignmentStatus getStatus(){return status;}
    public Instant getAssignedAt(){return assignedAt;} public Instant getAcceptedAt(){return acceptedAt;} public Instant getPickedUpAt(){return pickedUpAt;}
    public Instant getDeliveredAt(){return deliveredAt;} public Instant getFailedAt(){return failedAt;} public String getFailureReason(){return failureReason;}
    public void accept(){status=AssignmentStatus.ACCEPTED;acceptedAt=Instant.now();}
    public void pickup(){status=AssignmentStatus.PICKED_UP;pickedUpAt=Instant.now();}
    public void deliver(){status=AssignmentStatus.DELIVERED;deliveredAt=Instant.now();}
    public void fail(String reason){status=AssignmentStatus.FAILED;failedAt=Instant.now();failureReason=reason;}
    public void cancel(String reason){status=AssignmentStatus.CANCELLED;failureReason=reason;}
}
