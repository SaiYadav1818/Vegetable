package in.freshbasket.orders;

import in.freshbasket.user.AppUser;
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
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="collected_by_driver_user_id") private AppUser collectedBy;
    @Column(name="collected_at") private Instant collectedAt;
    @Column(nullable=false) private boolean reconciled=false;
    @Column(name="reconciled_at") private Instant reconciledAt;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="reconciled_by_user_id") private AppUser reconciledBy;
    @Column(name="reconciliation_note",length=300) private String reconciliationNote;
    @Column(name="created_at",nullable=false,updatable=false) private Instant createdAt;
    @PrePersist void create(){createdAt=Instant.now();}
    protected Payment(){}
    public Payment(CustomerOrder order,BigDecimal amount){this.order=order;this.method="COD";this.status=PaymentStatus.PENDING;this.amount=amount;}
    public Long getId(){return id;} public CustomerOrder getOrder(){return order;} public String getMethod(){return method;}
    public PaymentStatus getStatus(){return status;} public BigDecimal getAmount(){return amount;} public Instant getPaidAt(){return paidAt;}
    public AppUser getCollectedBy(){return collectedBy;} public Instant getCollectedAt(){return collectedAt;}
    public boolean isReconciled(){return reconciled;} public Instant getReconciledAt(){return reconciledAt;}
    public AppUser getReconciledBy(){return reconciledBy;} public String getReconciliationNote(){return reconciliationNote;}
    public void markCollected(AppUser driver,Instant at){
        this.status=PaymentStatus.PAID;this.paidAt=at;this.collectedBy=driver;this.collectedAt=at;
    }
    public void markUnpaid(){
        this.status=PaymentStatus.FAILED;
    }
    public void reconcile(AppUser admin,String note){
        this.reconciled=true;this.reconciledAt=Instant.now();this.reconciledBy=admin;this.reconciliationNote=note;
    }
}
