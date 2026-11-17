package in.freshbasket.shop;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class PublicShopController {
    private final ShopSettingsService service;

    public PublicShopController(ShopSettingsService service) {
        this.service = service;
    }

    @GetMapping("/api/shop/settings")
    public ShopSettingsDtos.ShopSettingsResponse settings() {
        return service.getSettingsResponse();
    }
}
