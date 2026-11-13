package in.freshbasket.catalog;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;

@Entity @Table(name="inventory")
public class Inventory {
    @Id @Column(name="product_id") private Long productId;
    @MapsId @OneToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="product_id") private Product product;
    @Column(nullable=false,precision=12,scale=3) private BigDecimal quantity;
    @Column(name="minimum_stock",nullable=false,precision=12,scale=3) private BigDecimal minimumStock;
    @Column(name="updated_at",nullable=false) private Instant updatedAt;
    @PrePersist @PreUpdate void updateTime(){updatedAt=Instant.now();}
    protected Inventory(){}
    public Inventory(Product product,BigDecimal quantity,BigDecimal minimumStock){this.product=product;this.quantity=quantity;this.minimumStock=minimumStock;}
    public Long getProductId(){return productId;} public BigDecimal getQuantity(){return quantity;} public BigDecimal getMinimumStock(){return minimumStock;}
    public void adjust(BigDecimal delta){quantity=quantity.add(delta);}
    public void minimumStock(BigDecimal value){minimumStock=value;}
}
