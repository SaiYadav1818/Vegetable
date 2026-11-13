package in.freshbasket.auth;

import in.freshbasket.user.AppUser;
import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="refresh_tokens",indexes={@Index(name="idx_refresh_tokens_user",columnList="user_id,revoked")})
public class RefreshToken {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="user_id",nullable=false) private AppUser user;
    @Column(name="token_hash",nullable=false,unique=true,length=64) private String tokenHash;
    @Column(name="expires_at",nullable=false) private Instant expiresAt;
    @Column(nullable=false) private boolean revoked=false;
    @Column(name="replaced_by_hash",length=64) private String replacedByHash;
    @Column(name="created_at",nullable=false,updatable=false) private Instant createdAt;
    @Column(name="updated_at",nullable=false) private Instant updatedAt;
    @PrePersist void create(){createdAt=updatedAt=Instant.now();} @PreUpdate void update(){updatedAt=Instant.now();}
    protected RefreshToken(){}
    public RefreshToken(AppUser user,String tokenHash,Instant expiresAt){this.user=user;this.tokenHash=tokenHash;this.expiresAt=expiresAt;}
    public Long getId(){return id;} public AppUser getUser(){return user;} public String getTokenHash(){return tokenHash;}
    public Instant getExpiresAt(){return expiresAt;} public boolean isRevoked(){return revoked;}
    public String getReplacedByHash(){return replacedByHash;}
    public void revoke(String replacementHash){this.revoked=true;this.replacedByHash=replacementHash;}
    public boolean isValid(){return !revoked && expiresAt.isAfter(Instant.now());}
}
