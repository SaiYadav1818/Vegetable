package in.freshbasket.shop;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.Instant;

public class ShopSettingsDtos {
    public record ShopSettingsResponse(
            Long id,
            String shopName,
            String contactPhone,
            String shopAddress,
            String openingTime,
            String closingTime,
            boolean openToday,
            BigDecimal minOrderValue,
            BigDecimal deliveryCharge,
            BigDecimal freeDeliveryThreshold,
            String announcementBanner,
            Instant updatedAt
    ) {
        public static ShopSettingsResponse from(ShopSettings s) {
            return new ShopSettingsResponse(
                    s.getId(),
                    s.getShopName(),
                    s.getContactPhone(),
                    s.getShopAddress(),
                    s.getOpeningTime(),
                    s.getClosingTime(),
                    s.isOpenToday(),
                    s.getMinOrderValue(),
                    s.getDeliveryCharge(),
                    s.getFreeDeliveryThreshold(),
                    s.getAnnouncementBanner(),
                    s.getUpdatedAt()
            );
        }
    }

    public record UpdateShopSettingsRequest(
            @NotBlank String shopName,
            @NotBlank String contactPhone,
            @NotBlank String shopAddress,
            @NotBlank String openingTime,
            @NotBlank String closingTime,
            @NotNull Boolean openToday,
            @NotNull @DecimalMin("0.0") BigDecimal minOrderValue,
            @NotNull @DecimalMin("0.0") BigDecimal deliveryCharge,
            @NotNull @DecimalMin("0.0") BigDecimal freeDeliveryThreshold,
            String announcementBanner
    ) {}
}
