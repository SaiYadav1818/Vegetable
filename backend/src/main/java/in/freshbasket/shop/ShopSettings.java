package in.freshbasket.shop;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "shop_settings")
public class ShopSettings {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "shop_name", nullable = false, length = 120)
    private String shopName;

    @Column(name = "contact_phone", nullable = false, length = 20)
    private String contactPhone;

    @Column(name = "shop_address", nullable = false, length = 300)
    private String shopAddress;

    @Column(name = "opening_time", nullable = false, length = 10)
    private String openingTime = "06:30";

    @Column(name = "closing_time", nullable = false, length = 10)
    private String closingTime = "21:30";

    @Column(name = "is_open_today", nullable = false)
    private boolean openToday = true;

    @Column(name = "min_order_value", nullable = false, precision = 12, scale = 2)
    private BigDecimal minOrderValue = BigDecimal.valueOf(100.00);

    @Column(name = "delivery_charge", nullable = false, precision = 12, scale = 2)
    private BigDecimal deliveryCharge = BigDecimal.valueOf(30.00);

    @Column(name = "free_delivery_threshold", nullable = false, precision = 12, scale = 2)
    private BigDecimal freeDeliveryThreshold = BigDecimal.valueOf(500.00);

    @Column(name = "announcement_banner", length = 300)
    private String announcementBanner;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    @PreUpdate
    void touch() {
        updatedAt = Instant.now();
    }

    protected ShopSettings() {}

    public ShopSettings(String shopName, String contactPhone, String shopAddress, String openingTime,
                        String closingTime, boolean openToday, BigDecimal minOrderValue,
                        BigDecimal deliveryCharge, BigDecimal freeDeliveryThreshold, String announcementBanner) {
        this.shopName = shopName;
        this.contactPhone = contactPhone;
        this.shopAddress = shopAddress;
        this.openingTime = openingTime;
        this.closingTime = closingTime;
        this.openToday = openToday;
        this.minOrderValue = minOrderValue;
        this.deliveryCharge = deliveryCharge;
        this.freeDeliveryThreshold = freeDeliveryThreshold;
        this.announcementBanner = announcementBanner;
        this.updatedAt = Instant.now();
    }

    public Long getId() { return id; }
    public String getShopName() { return shopName; }
    public String getContactPhone() { return contactPhone; }
    public String getShopAddress() { return shopAddress; }
    public String getOpeningTime() { return openingTime; }
    public String getClosingTime() { return closingTime; }
    public boolean isOpenToday() { return openToday; }
    public BigDecimal getMinOrderValue() { return minOrderValue; }
    public BigDecimal getDeliveryCharge() { return deliveryCharge; }
    public BigDecimal getFreeDeliveryThreshold() { return freeDeliveryThreshold; }
    public String getAnnouncementBanner() { return announcementBanner; }
    public Instant getUpdatedAt() { return updatedAt; }

    public void update(String shopName, String contactPhone, String shopAddress, String openingTime,
                       String closingTime, boolean openToday, BigDecimal minOrderValue,
                       BigDecimal deliveryCharge, BigDecimal freeDeliveryThreshold, String announcementBanner) {
        this.shopName = shopName;
        this.contactPhone = contactPhone;
        this.shopAddress = shopAddress;
        this.openingTime = openingTime;
        this.closingTime = closingTime;
        this.openToday = openToday;
        this.minOrderValue = minOrderValue;
        this.deliveryCharge = deliveryCharge;
        this.freeDeliveryThreshold = freeDeliveryThreshold;
        this.announcementBanner = announcementBanner;
        this.updatedAt = Instant.now();
    }
}
