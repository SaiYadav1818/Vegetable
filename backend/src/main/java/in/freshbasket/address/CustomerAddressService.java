package in.freshbasket.address;

import in.freshbasket.user.AppUser;
import in.freshbasket.user.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
public class CustomerAddressService {
    private final CustomerAddressRepository addressRepository;
    private final UserRepository userRepository;

    public CustomerAddressService(CustomerAddressRepository addressRepository, UserRepository userRepository) {
        this.addressRepository = addressRepository;
        this.userRepository = userRepository;
    }

    private AppUser findCustomer(String email) {
        return userRepository.findByEmail(email.toLowerCase())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
    }

    @Transactional(readOnly = true)
    public List<AddressDtos.AddressResponse> listAddresses(String email) {
        AppUser customer = findCustomer(email);
        return addressRepository.findByCustomer_IdOrderByIsDefaultDescCreatedAtDesc(customer.getId())
                .stream()
                .map(AddressDtos.AddressResponse::from)
                .toList();
    }

    @Transactional
    public AddressDtos.AddressResponse createAddress(String email, AddressDtos.CreateAddressRequest req) {
        AppUser customer = findCustomer(email);
        long existingCount = addressRepository.countByCustomer_Id(customer.getId());
        boolean makeDefault = (existingCount == 0) || Boolean.TRUE.equals(req.isDefault());

        if (makeDefault && existingCount > 0) {
            addressRepository.resetDefaultsForCustomer(customer.getId());
        }

        CustomerAddress address = new CustomerAddress(
                customer,
                req.label(),
                req.recipientName().trim(),
                req.recipientPhone().trim(),
                req.addressLine().trim(),
                req.houseNumber() != null ? req.houseNumber().trim() : null,
                req.area().trim(),
                req.landmark() != null ? req.landmark().trim() : null,
                req.pincode().trim(),
                makeDefault
        );

        return AddressDtos.AddressResponse.from(addressRepository.save(address));
    }

    @Transactional
    public AddressDtos.AddressResponse updateAddress(String email, Long id, AddressDtos.UpdateAddressRequest req) {
        AppUser customer = findCustomer(email);
        CustomerAddress address = addressRepository.findByIdAndCustomer_Id(id, customer.getId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Address not found"));

        boolean makeDefault = Boolean.TRUE.equals(req.isDefault());
        if (makeDefault && !address.isDefault()) {
            addressRepository.resetDefaultsForCustomer(customer.getId());
        }

        address.update(
                req.label(),
                req.recipientName().trim(),
                req.recipientPhone().trim(),
                req.addressLine().trim(),
                req.houseNumber() != null ? req.houseNumber().trim() : null,
                req.area().trim(),
                req.landmark() != null ? req.landmark().trim() : null,
                req.pincode().trim(),
                makeDefault || address.isDefault()
        );

        return AddressDtos.AddressResponse.from(addressRepository.save(address));
    }

    @Transactional
    public void deleteAddress(String email, Long id) {
        AppUser customer = findCustomer(email);
        CustomerAddress address = addressRepository.findByIdAndCustomer_Id(id, customer.getId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Address not found"));
        boolean wasDefault = address.isDefault();
        addressRepository.delete(address);

        if (wasDefault) {
            addressRepository.findByCustomer_IdOrderByIsDefaultDescCreatedAtDesc(customer.getId())
                    .stream()
                    .findFirst()
                    .ifPresent(next -> next.setDefault(true));
        }
    }

    @Transactional
    public AddressDtos.AddressResponse setDefaultAddress(String email, Long id) {
        AppUser customer = findCustomer(email);
        CustomerAddress address = addressRepository.findByIdAndCustomer_Id(id, customer.getId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Address not found"));

        addressRepository.resetDefaultsForCustomer(customer.getId());
        address.setDefault(true);
        return AddressDtos.AddressResponse.from(addressRepository.save(address));
    }
}
