package in.freshbasket.shop;

import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/admin/shop-settings")
public class AdminShopController {
    private final ShopSettingsService service;

    public AdminShopController(ShopSettingsService service) {
        this.service = service;
    }

    @GetMapping
    public ShopSettingsDtos.ShopSettingsResponse getSettings() {
        return service.getSettingsResponse();
    }

    @PutMapping
    public ShopSettingsDtos.ShopSettingsResponse updateSettings(@Valid @RequestBody ShopSettingsDtos.UpdateShopSettingsRequest req) {
        return service.updateSettings(req);
    }
}
