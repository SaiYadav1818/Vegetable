package in.freshbasket.shop;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class ShopSettingsServiceTest {
    private ShopSettingsRepository repository;
    private ShopSettingsService service;

    @BeforeEach
    void setUp() {
        repository = mock(ShopSettingsRepository.class);
        service = new ShopSettingsService(repository);
    }

    @Test
    void getOrCreateSettings_createsDefaultIfNotFound() {
        when(repository.findFirstByOrderByIdAsc()).thenReturn(Optional.empty());
        when(repository.save(any(ShopSettings.class))).thenAnswer(inv -> inv.getArgument(0));

        ShopSettings settings = service.getOrCreateSettings();
        assertNotNull(settings);
        assertEquals("FreshBasket Neighborhood Mart", settings.getShopName());
        assertTrue(settings.isOpenToday());
        assertEquals(BigDecimal.valueOf(100.00), settings.getMinOrderValue());
        verify(repository).save(any(ShopSettings.class));
    }

    @Test
    void calculateDeliveryCharge_appliesFreeDeliveryThreshold() {
        ShopSettings settings = new ShopSettings("Shop", "1234567890", "Address", "06:00", "22:00",
                true, BigDecimal.valueOf(100), BigDecimal.valueOf(30), BigDecimal.valueOf(500), "Notice");
        when(repository.findFirstByOrderByIdAsc()).thenReturn(Optional.of(settings));

        BigDecimal chargeUnder = service.calculateDeliveryCharge(BigDecimal.valueOf(250));
        assertEquals(BigDecimal.valueOf(30), chargeUnder);

        BigDecimal chargeOver = service.calculateDeliveryCharge(BigDecimal.valueOf(500));
        assertEquals(BigDecimal.ZERO, chargeOver);

        BigDecimal chargeMuchOver = service.calculateDeliveryCharge(BigDecimal.valueOf(750));
        assertEquals(BigDecimal.ZERO, chargeMuchOver);
    }

    @Test
    void updateSettings_updatesAllFields() {
        ShopSettings existing = new ShopSettings("Old Shop", "1234567890", "Old Address", "06:00", "22:00",
                true, BigDecimal.valueOf(100), BigDecimal.valueOf(30), BigDecimal.valueOf(500), null);
        when(repository.findFirstByOrderByIdAsc()).thenReturn(Optional.of(existing));
        when(repository.save(any(ShopSettings.class))).thenAnswer(inv -> inv.getArgument(0));

        ShopSettingsDtos.UpdateShopSettingsRequest update = new ShopSettingsDtos.UpdateShopSettingsRequest(
                "New Shop Name", "9998887770", "New Address", "07:00", "21:00",
                false, BigDecimal.valueOf(150), BigDecimal.valueOf(40), BigDecimal.valueOf(600), "Closed for holiday"
        );

        ShopSettingsDtos.ShopSettingsResponse resp = service.updateSettings(update);
        assertEquals("New Shop Name", resp.shopName());
        assertEquals("9998887770", resp.contactPhone());
        assertFalse(resp.openToday());
        assertEquals("Closed for holiday", resp.announcementBanner());
        assertEquals(BigDecimal.valueOf(40), resp.deliveryCharge());
    }
}
