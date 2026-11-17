package in.freshbasket.address;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface CustomerAddressRepository extends JpaRepository<CustomerAddress, Long> {
    List<CustomerAddress> findByCustomer_IdOrderByIsDefaultDescCreatedAtDesc(Long customerId);

    Optional<CustomerAddress> findByIdAndCustomer_Id(Long id, Long customerId);

    @Modifying
    @Query("UPDATE CustomerAddress a SET a.isDefault = false WHERE a.customer.id = :customerId")
    void resetDefaultsForCustomer(@Param("customerId") Long customerId);

    long countByCustomer_Id(Long customerId);
}
