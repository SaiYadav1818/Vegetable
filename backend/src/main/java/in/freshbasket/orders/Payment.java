package in.freshbasket.orders;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;

@Entity @Table(name="payments")
public class Payment {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @OneToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="order_id",nullable=false,unique=true) private CustomerOrder order;
    @Column(nullable=false,length=16) private String method;
    @Enumerated(EnumType.STRING) @Column(nullable=false,length=16) private PaymentStatus status;
    @Column(nullable=false,precision=12,scale=2) private BigDecimal amount;
    @Column(name="paid_at") private Instant paidAt;
    @Column(name="created_at",nullable=false,updatable=false) private Instant createdAt;
    @PrePersist void create(){createdAt=Instant.now();}
    protected Payment(){}
    public Payment(CustomerOrder order,BigDecimal amount){this.order=order;this.method="COD";this.status=PaymentStatus.PENDING;this.amount=amount;}
    public void markPaid(){status=PaymentStatus.PAID;paidAt=Instant.now();}
}
