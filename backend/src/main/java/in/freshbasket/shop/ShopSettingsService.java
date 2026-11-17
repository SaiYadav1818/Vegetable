package in.freshbasket.shop;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;

@Service
public class ShopSettingsService {
    private final ShopSettingsRepository repository;

    public ShopSettingsService(ShopSettingsRepository repository) {
        this.repository = repository;
    }

    @Transactional(readOnly = true)
    public ShopSettings getOrCreateSettings() {
        return repository.findFirstByOrderByIdAsc().orElseGet(() -> {
            ShopSettings initial = new ShopSettings(
                    "FreshBasket Neighborhood Mart",
                    "+91 98765 43210",
                    "12/4 Green Avenue, Sector 5, Bangalore - 560001",
                    "06:30",
                    "21:30",
                    true,
                    BigDecimal.valueOf(100.00),
                    BigDecimal.valueOf(30.00),
                    BigDecimal.valueOf(500.00),
                    "Fresh morning farm arrivals available daily from 6:30 AM!"
            );
            return repository.save(initial);
        });
    }

    @Transactional(readOnly = true)
    public ShopSettingsDtos.ShopSettingsResponse getSettingsResponse() {
        return ShopSettingsDtos.ShopSettingsResponse.from(getOrCreateSettings());
    }

    @Transactional
    public ShopSettingsDtos.ShopSettingsResponse updateSettings(ShopSettingsDtos.UpdateShopSettingsRequest req) {
        ShopSettings settings = getOrCreateSettings();
        settings.update(
                req.shopName().trim(),
                req.contactPhone().trim(),
                req.shopAddress().trim(),
                req.openingTime().trim(),
                req.closingTime().trim(),
                req.openToday(),
                req.minOrderValue(),
                req.deliveryCharge(),
                req.freeDeliveryThreshold(),
                req.announcementBanner() != null ? req.announcementBanner().trim() : null
        );
        return ShopSettingsDtos.ShopSettingsResponse.from(repository.save(settings));
    }

    @Transactional(readOnly = true)
    public BigDecimal calculateDeliveryCharge(BigDecimal subtotal) {
        ShopSettings settings = getOrCreateSettings();
        if (subtotal.compareTo(settings.getFreeDeliveryThreshold()) >= 0) {
            return BigDecimal.ZERO;
        }
        return settings.getDeliveryCharge();
    }
}
