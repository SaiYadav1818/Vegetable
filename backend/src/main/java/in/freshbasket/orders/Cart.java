package in.freshbasket.orders;

import in.freshbasket.user.AppUser;
import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="carts")
public class Cart {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @OneToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="customer_user_id",nullable=false,unique=true) private AppUser customer;
    @Column(name="created_at",nullable=false,updatable=false) private Instant createdAt;
    @Column(name="updated_at",nullable=false) private Instant updatedAt;
    @PrePersist void create(){createdAt=updatedAt=Instant.now();} @PreUpdate void update(){updatedAt=Instant.now();}
    protected Cart(){} public Cart(AppUser customer){this.customer=customer;}
    public Long getId(){return id;} public AppUser getCustomer(){return customer;}
}
