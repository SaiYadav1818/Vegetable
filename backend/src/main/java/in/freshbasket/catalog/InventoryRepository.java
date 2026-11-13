package in.freshbasket.catalog;

import java.util.Optional;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
public interface InventoryRepository extends JpaRepository<Inventory,Long>{
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select i from Inventory i where i.productId=:id") Optional<Inventory> findLockedByProductId(@Param("id") Long id);
}
