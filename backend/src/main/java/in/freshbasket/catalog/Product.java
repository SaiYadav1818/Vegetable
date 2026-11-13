package in.freshbasket.catalog;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;

@Entity @Table(name="products", indexes={@Index(name="idx_products_category_active",columnList="category_id,active"),@Index(name="idx_products_name",columnList="name")})
public class Product {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @Column(nullable=false,length=120) private String name;
    @Column(length=1000) private String description;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="category_id",nullable=false) private Category category;
    @Column(nullable=false,precision=10,scale=2) private BigDecimal price;
    @Enumerated(EnumType.STRING) @Column(nullable=false,length=12) private ProductUnit unit;
    @Column(name="image_url",length=500) private String imageUrl;
    @Column(nullable=false) private boolean active=true;
    @Column(nullable=false) private boolean available=true;
    @Column(name="created_at",nullable=false,updatable=false) private Instant createdAt;
    @Column(name="updated_at",nullable=false) private Instant updatedAt;
    @PrePersist void create(){createdAt=updatedAt=Instant.now();}
    @PreUpdate void update(){updatedAt=Instant.now();}
    protected Product(){}
    public Product(String name,String description,Category category,BigDecimal price,ProductUnit unit,String imageUrl){this.name=name;this.description=description;this.category=category;this.price=price;this.unit=unit;this.imageUrl=imageUrl;}
    public Long getId(){return id;} public String getName(){return name;} public String getDescription(){return description;} public Category getCategory(){return category;}
    public BigDecimal getPrice(){return price;} public ProductUnit getUnit(){return unit;} public String getImageUrl(){return imageUrl;} public boolean isActive(){return active;} public boolean isAvailable(){return available;}
    public void update(String name,String description,Category category,BigDecimal price,ProductUnit unit,String imageUrl,boolean active,boolean available){this.name=name;this.description=description;this.category=category;this.price=price;this.unit=unit;this.imageUrl=imageUrl;this.active=active;this.available=available;}
    public void deactivate(){active=false;available=false;}
    public void imageUrl(String value){imageUrl=value;}
}
