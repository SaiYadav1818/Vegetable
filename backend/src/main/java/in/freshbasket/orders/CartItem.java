package in.freshbasket.orders;

import in.freshbasket.catalog.Product;
import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;

@Entity @Table(name="cart_items",uniqueConstraints=@UniqueConstraint(name="uq_cart_product",columnNames={"cart_id","product_id"}))
public class CartItem {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="cart_id",nullable=false) private Cart cart;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="product_id",nullable=false) private Product product;
    @Column(nullable=false,precision=12,scale=3) private BigDecimal quantity;
    @Column(name="created_at",nullable=false,updatable=false) private Instant createdAt;
    @Column(name="updated_at",nullable=false) private Instant updatedAt;
    @PrePersist void create(){createdAt=updatedAt=Instant.now();} @PreUpdate void update(){updatedAt=Instant.now();}
    protected CartItem(){} public CartItem(Cart cart,Product product,BigDecimal quantity){this.cart=cart;this.product=product;this.quantity=quantity;}
    public Long getId(){return id;} public Cart getCart(){return cart;} public Product getProduct(){return product;} public BigDecimal getQuantity(){return quantity;}
    public void setQuantity(BigDecimal quantity){this.quantity=quantity;}
}
