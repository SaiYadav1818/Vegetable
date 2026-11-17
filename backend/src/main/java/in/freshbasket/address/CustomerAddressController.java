package in.freshbasket.address;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/customer/addresses")
@PreAuthorize("hasRole('CUSTOMER')")
public class CustomerAddressController {
    private final CustomerAddressService addressService;

    public CustomerAddressController(CustomerAddressService addressService) {
        this.addressService = addressService;
    }

    @GetMapping
    public List<AddressDtos.AddressResponse> list(Authentication auth) {
        return addressService.listAddresses(auth.getName());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AddressDtos.AddressResponse create(Authentication auth, @Valid @RequestBody AddressDtos.CreateAddressRequest req) {
        return addressService.createAddress(auth.getName(), req);
    }

    @PutMapping("/{id}")
    public AddressDtos.AddressResponse update(Authentication auth, @PathVariable Long id, @Valid @RequestBody AddressDtos.UpdateAddressRequest req) {
        return addressService.updateAddress(auth.getName(), id, req);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(Authentication auth, @PathVariable Long id) {
        addressService.deleteAddress(auth.getName(), id);
    }

    @PutMapping("/{id}/default")
    public AddressDtos.AddressResponse setDefault(Authentication auth, @PathVariable Long id) {
        return addressService.setDefaultAddress(auth.getName(), id);
    }
}
