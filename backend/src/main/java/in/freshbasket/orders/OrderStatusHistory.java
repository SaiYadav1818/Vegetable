package in.freshbasket.orders;

import in.freshbasket.user.AppUser;
import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="order_status_history",indexes=@Index(name="idx_order_history_order_created",columnList="order_id,created_at"))
public class OrderStatusHistory {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="order_id",nullable=false) private CustomerOrder order;
    @Enumerated(EnumType.STRING) @Column(name="from_status",length=24) private OrderStatus fromStatus;
    @Enumerated(EnumType.STRING) @Column(name="to_status",nullable=false,length=24) private OrderStatus toStatus;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="changed_by_user_id") private AppUser actor;
    @Column(length=300) private String reason;
    @Column(name="created_at",nullable=false,updatable=false) private Instant createdAt;
    @PrePersist void create(){createdAt=Instant.now();}
    protected OrderStatusHistory(){}
    public OrderStatusHistory(CustomerOrder order,OrderStatus from,OrderStatus to,AppUser actor,String reason){this.order=order;this.fromStatus=from;this.toStatus=to;this.actor=actor;this.reason=reason;}
    public OrderStatus getFromStatus(){return fromStatus;} public OrderStatus getToStatus(){return toStatus;} public String getReason(){return reason;} public Instant getCreatedAt(){return createdAt;}
}
