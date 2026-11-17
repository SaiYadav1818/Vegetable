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
    long countByStatus(OrderStatus status);
    long countByStatusIn(Collection<OrderStatus> statuses);
    @Query("select coalesce(sum(o.totalAmount), 0) from CustomerOrder o where o.status = :status")
    java.math.BigDecimal sumTotalAmountByStatus(@Param("status") OrderStatus status);
    @Query("select coalesce(sum(o.totalAmount), 0) from CustomerOrder o where o.status = :status and o.createdAt >= :since")
    java.math.BigDecimal sumTotalAmountByStatusAndCreatedAtAfter(@Param("status") OrderStatus status, @Param("since") java.time.Instant since);
}
interface OrderItemRepository extends JpaRepository<OrderItem,Long>{
    List<OrderItem> findByOrder_IdOrderById(Long orderId);
    @Query("select i.productId, i.productName, sum(i.quantity), sum(i.lineTotal) from OrderItem i join i.order o where o.status = in.freshbasket.orders.OrderStatus.DELIVERED group by i.productId, i.productName order by sum(i.quantity) desc")
    List<Object[]> findTopSellingDelivered(Pageable pageable);
}
interface OrderHistoryRepository extends JpaRepository<OrderStatusHistory,Long>{List<OrderStatusHistory> findByOrder_IdOrderByCreatedAtAsc(Long orderId);}
interface PaymentRepository extends JpaRepository<Payment,Long>{
    Optional<Payment> findByOrder_Id(Long orderId);
    List<Payment> findByStatusAndReconciledFalseOrderByPaidAtAsc(PaymentStatus status);
    List<Payment> findByCollectedBy_IdAndReconciledFalse(Long driverId);
    @Query("select count(p) from Payment p where p.order.status = in.freshbasket.orders.OrderStatus.DELIVERED and p.status != in.freshbasket.orders.PaymentStatus.PAID")
    long countUnpaidDelivered();
    @Query("select coalesce(sum(p.amount), 0) from Payment p where p.status = in.freshbasket.orders.PaymentStatus.PAID")
    java.math.BigDecimal sumTotalPaid();
    @Query("select coalesce(sum(p.amount), 0) from Payment p where p.status = in.freshbasket.orders.PaymentStatus.PAID and p.reconciled = false")
    java.math.BigDecimal sumUnreconciledPaid();
}
interface DeliveryOtpRepository extends JpaRepository<DeliveryOtp,Long>{
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select d from DeliveryOtp d where d.orderId=:id") Optional<DeliveryOtp> findLocked(@Param("id") Long orderId);
}
