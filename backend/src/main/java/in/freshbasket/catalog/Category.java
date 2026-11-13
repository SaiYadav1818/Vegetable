package in.freshbasket.catalog;

import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="categories")
public class Category {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @Column(nullable=false, unique=true, length=80) private String name;
    @Column(length=300) private String description;
    @Column(nullable=false) private boolean active=true;
    @Column(name="created_at", nullable=false, updatable=false) private Instant createdAt;
    @Column(name="updated_at", nullable=false) private Instant updatedAt;
    @PrePersist void create(){createdAt=updatedAt=Instant.now();}
    @PreUpdate void update(){updatedAt=Instant.now();}
    protected Category(){}
    public Category(String name,String description){this.name=name;this.description=description;}
    public Long getId(){return id;} public String getName(){return name;} public String getDescription(){return description;} public boolean isActive(){return active;}
    public void update(String name,String description,boolean active){this.name=name;this.description=description;this.active=active;}
}
