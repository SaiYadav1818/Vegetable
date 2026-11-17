package in.freshbasket.address;

import in.freshbasket.user.AppUser;
import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "customer_addresses", indexes = {
        @Index(name = "idx_customer_addresses_user", columnList = "customer_user_id, is_default")
})
public class CustomerAddress {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "customer_user_id", nullable = false)
    private AppUser customer;

    @Column(nullable = false, length = 50)
    private String label = "Home";

    @Column(name = "recipient_name", nullable = false, length = 120)
    private String recipientName;

    @Column(name = "recipient_phone", nullable = false, length = 20)
    private String recipientPhone;

    @Column(name = "address_line", nullable = false, length = 300)
    private String addressLine;

    @Column(name = "house_number", length = 100)
    private String houseNumber;

    @Column(nullable = false, length = 120)
    private String area;

    @Column(length = 160)
    private String landmark;

    @Column(nullable = false, length = 6)
    private String pincode;

    @Column(name = "is_default", nullable = false)
    private boolean isDefault = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void prePersist() {
        createdAt = updatedAt = Instant.now();
    }

    @PreUpdate
    void preUpdate() {
        updatedAt = Instant.now();
    }

    protected CustomerAddress() {}

    public CustomerAddress(AppUser customer, String label, String recipientName, String recipientPhone,
                           String addressLine, String houseNumber, String area, String landmark,
                           String pincode, boolean isDefault) {
        this.customer = customer;
        this.label = (label != null && !label.isBlank()) ? label.trim() : "Home";
        this.recipientName = recipientName;
        this.recipientPhone = recipientPhone;
        this.addressLine = addressLine;
        this.houseNumber = houseNumber;
        this.area = area;
        this.landmark = landmark;
        this.pincode = pincode;
        this.isDefault = isDefault;
    }

    public Long getId() { return id; }
    public AppUser getCustomer() { return customer; }
    public String getLabel() { return label; }
    public String getRecipientName() { return recipientName; }
    public String getRecipientPhone() { return recipientPhone; }
    public String getAddressLine() { return addressLine; }
    public String getHouseNumber() { return houseNumber; }
    public String getArea() { return area; }
    public String getLandmark() { return landmark; }
    public String getPincode() { return pincode; }
    public boolean isDefault() { return isDefault; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }

    public void update(String label, String recipientName, String recipientPhone, String addressLine,
                       String houseNumber, String area, String landmark, String pincode, boolean isDefault) {
        if (label != null && !label.isBlank()) this.label = label.trim();
        this.recipientName = recipientName;
        this.recipientPhone = recipientPhone;
        this.addressLine = addressLine;
        this.houseNumber = houseNumber;
        this.area = area;
        this.landmark = landmark;
        this.pincode = pincode;
        this.isDefault = isDefault;
    }

    public void setDefault(boolean isDefault) {
        this.isDefault = isDefault;
    }
}
