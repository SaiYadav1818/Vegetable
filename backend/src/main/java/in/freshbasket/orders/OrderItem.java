package in.freshbasket.orders;

import in.freshbasket.catalog.Product;
import in.freshbasket.catalog.ProductUnit;
import jakarta.persistence.*;
import java.math.BigDecimal;

@Entity @Table(name="order_items",indexes=@Index(name="idx_order_items_order",columnList="order_id"))
public class OrderItem {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="order_id",nullable=false) private CustomerOrder order;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="product_id",nullable=false) private Product product;
    @Column(name="product_name",nullable=false,length=120) private String productName;
    @Enumerated(EnumType.STRING) @Column(nullable=false,length=12) private ProductUnit unit;
    @Column(nullable=false,precision=12,scale=3) private BigDecimal quantity;
    @Column(name="unit_price",nullable=false,precision=10,scale=2) private BigDecimal unitPrice;
    @Column(name="line_total",nullable=false,precision=12,scale=2) private BigDecimal lineTotal;
    protected OrderItem(){}
    public OrderItem(CustomerOrder order,Product product,BigDecimal quantity,BigDecimal price){this.order=order;this.product=product;this.productName=product.getName();this.unit=product.getUnit();this.quantity=quantity;this.unitPrice=price;this.lineTotal=price.multiply(quantity).setScale(2,java.math.RoundingMode.HALF_UP);}
    public Long getProductId(){return product.getId();} public String getProductName(){return productName;} public ProductUnit getUnit(){return unit;} public BigDecimal getQuantity(){return quantity;} public BigDecimal getUnitPrice(){return unitPrice;} public BigDecimal getLineTotal(){return lineTotal;}
}
