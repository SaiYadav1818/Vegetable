package in.freshbasket.address;

import in.freshbasket.user.AppUser;
import in.freshbasket.user.Role;
import in.freshbasket.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class CustomerAddressServiceTest {
    private CustomerAddressRepository addressRepository;
    private UserRepository userRepository;
    private CustomerAddressService service;
    private AppUser customer;

    @BeforeEach
    void setUp() {
        addressRepository = mock(CustomerAddressRepository.class);
        userRepository = mock(UserRepository.class);
        service = new CustomerAddressService(addressRepository, userRepository);

        customer = new AppUser("customer@freshbasket.in", "hash", "Sai Customer", "9876543210", Role.CUSTOMER);
        ReflectionTestUtils.setField(customer, "id", 101L);
        when(userRepository.findByEmail("customer@freshbasket.in")).thenReturn(Optional.of(customer));
    }

    @Test
    void createAddress_firstAddressBecomesDefaultAutomatically() {
        when(addressRepository.countByCustomer_Id(101L)).thenReturn(0L);
        when(addressRepository.save(any(CustomerAddress.class))).thenAnswer(inv -> inv.getArgument(0));

        AddressDtos.CreateAddressRequest req = new AddressDtos.CreateAddressRequest(
                "Home", "Sai Customer", "9876543210", "Flat 402, Green Towers",
                "402", "Indiranagar", "Near Metro", "560038", false
        );

        AddressDtos.AddressResponse res = service.createAddress("customer@freshbasket.in", req);
        assertNotNull(res);
        assertTrue(res.isDefault(), "First address must be made default automatically");
        assertEquals("Home", res.label());
        assertEquals("560038", res.pincode());
    }

    @Test
    void createAddress_explicitDefaultResetsPreviousDefaults() {
        when(addressRepository.countByCustomer_Id(101L)).thenReturn(1L);
        when(addressRepository.save(any(CustomerAddress.class))).thenAnswer(inv -> inv.getArgument(0));

        AddressDtos.CreateAddressRequest req = new AddressDtos.CreateAddressRequest(
                "Work", "Sai Office", "9876543210", "Tech Park Building 3",
                "3B", "Whitefield", "ITPL", "560066", true
        );

        AddressDtos.AddressResponse res = service.createAddress("customer@freshbasket.in", req);
        assertTrue(res.isDefault());
        verify(addressRepository).resetDefaultsForCustomer(101L);
    }

    @Test
    void setDefaultAddress_switchesDefaultSuccessfully() {
        CustomerAddress address = new CustomerAddress(customer, "Parents", "Dad", "9876543210",
                "12 Cross", "12", "Jayanagar", "Park", "560041", false);
        ReflectionTestUtils.setField(address, "id", 55L);

        when(addressRepository.findByIdAndCustomer_Id(55L, 101L)).thenReturn(Optional.of(address));
        when(addressRepository.save(any(CustomerAddress.class))).thenAnswer(inv -> inv.getArgument(0));

        AddressDtos.AddressResponse res = service.setDefaultAddress("customer@freshbasket.in", 55L);
        assertTrue(res.isDefault());
        verify(addressRepository).resetDefaultsForCustomer(101L);
    }
}
