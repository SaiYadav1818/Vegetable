package in.freshbasket.orders;

import java.util.*;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.*;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

interface OrderRepository extends JpaRepository<CustomerOrder,Long>{
    Page<CustomerOrder> findByCustomer_Id(Long customerId,Pageable pageable);
    Optional<CustomerOrder> findByCustomer_IdAndIdempotencyKey(Long customerId,String idempotencyKey);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select o from CustomerOrder o where o.id=:id") Optional<CustomerOrder> findLocked(@Param("id") Long id);
    Page<CustomerOrder> findAll(Pageable pageable);
}
interface OrderItemRepository extends JpaRepository<OrderItem,Long>{List<OrderItem> findByOrder_IdOrderById(Long orderId);}
interface OrderHistoryRepository extends JpaRepository<OrderStatusHistory,Long>{List<OrderStatusHistory> findByOrder_IdOrderByCreatedAtAsc(Long orderId);}
interface PaymentRepository extends JpaRepository<Payment,Long>{
    Optional<Payment> findByOrder_Id(Long orderId);
    List<Payment> findByStatusAndReconciledFalseOrderByPaidAtAsc(PaymentStatus status);
    List<Payment> findByCollectedBy_IdAndReconciledFalse(Long driverId);
    @Query("select count(p) from Payment p where p.order.status = in.freshbasket.orders.OrderStatus.DELIVERED and p.status != in.freshbasket.orders.PaymentStatus.PAID")
    long countUnpaidDelivered();
}
interface DeliveryOtpRepository extends JpaRepository<DeliveryOtp,Long>{
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select d from DeliveryOtp d where d.orderId=:id") Optional<DeliveryOtp> findLocked(@Param("id") Long orderId);
}
