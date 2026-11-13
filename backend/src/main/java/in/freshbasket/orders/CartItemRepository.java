package in.freshbasket.orders;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
public interface CartItemRepository extends JpaRepository<CartItem,Long>{
    List<CartItem> findByCart_IdOrderByProduct_Id(Long cartId);
    Optional<CartItem> findByIdAndCart_Id(Long id,Long cartId);
    void deleteByCart_Id(Long cartId);
}
