package in.freshbasket.catalog;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;

@Entity @Table(name="inventory_transactions",indexes=@Index(name="idx_inventory_tx_product_created",columnList="product_id,created_at"))
public class InventoryTransaction {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="product_id",nullable=false) private Product product;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="actor_user_id") private in.freshbasket.user.AppUser actor;
    @Column(name="quantity_delta",nullable=false,precision=12,scale=3) private BigDecimal quantityDelta;
    @Column(name="quantity_after",nullable=false,precision=12,scale=3) private BigDecimal quantityAfter;
    @Column(nullable=false,length=40) private String reason;
    @Column(length=300) private String note;
    @Column(name="created_at",nullable=false,updatable=false) private Instant createdAt;
    @PrePersist void create(){createdAt=Instant.now();}
    protected InventoryTransaction(){}
    public InventoryTransaction(Product product,in.freshbasket.user.AppUser actor,BigDecimal delta,BigDecimal after,String reason,String note){this.product=product;this.actor=actor;this.quantityDelta=delta;this.quantityAfter=after;this.reason=reason;this.note=note;}
    public Long getId(){return id;} public BigDecimal getQuantityDelta(){return quantityDelta;} public BigDecimal getQuantityAfter(){return quantityAfter;} public String getReason(){return reason;} public String getNote(){return note;} public Instant getCreatedAt(){return createdAt;}
}
