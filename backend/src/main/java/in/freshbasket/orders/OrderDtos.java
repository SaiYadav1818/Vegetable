package in.freshbasket.orders;

import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

public final class OrderDtos {
    private OrderDtos(){}
    public record CartItemRequest(@NotNull Long productId,@NotNull @DecimalMin("0.001") @Digits(integer=9,fraction=3) BigDecimal quantity){}
    public record CartQuantityRequest(@NotNull @DecimalMin("0.001") @Digits(integer=9,fraction=3) BigDecimal quantity){}
    public record CartLineResponse(Long id,Long productId,String name,String imageUrl,String unit,BigDecimal price,BigDecimal quantity,BigDecimal stock,BigDecimal lineTotal,boolean available){}
    public record CartResponse(List<CartLineResponse> items,BigDecimal subtotal){}
    public record CheckoutRequest(
            @Size(max=64) String idempotencyKey,
            @NotNull @DecimalMin("0.00") @Digits(integer=10,fraction=2) BigDecimal expectedSubtotal,
            @NotBlank @Size(max=120) String recipientName,@NotBlank @Pattern(regexp="^[0-9+() -]{7,20}$") String recipientPhone,
            @NotBlank @Size(max=300) String addressLine,@Size(max=100) String houseNumber,@NotBlank @Size(max=120) String area,
            @Size(max=160) String landmark,@NotBlank @Pattern(regexp="^[0-9]{6}$") String pincode,@Size(max=500) String deliveryInstructions,
            @NotNull @FutureOrPresent LocalDate deliveryDate,@NotNull DeliverySlot deliverySlot,
            @DecimalMin("-90.0") @DecimalMax("90.0") BigDecimal latitude,@DecimalMin("-180.0") @DecimalMax("180.0") BigDecimal longitude){}
    public record OrderItemResponse(String name,String unit,BigDecimal quantity,BigDecimal unitPrice,BigDecimal lineTotal){}
    public record StatusEvent(OrderStatus fromStatus,OrderStatus toStatus,String reason,Instant createdAt){}
    public record DriverLocationResponse(BigDecimal latitude,BigDecimal longitude,Instant updatedAt){}
    public record OrderResponse(Long id,String orderNumber,OrderStatus status,String paymentMethod,PaymentStatus paymentStatus,
            BigDecimal subtotal,BigDecimal deliveryCharge,BigDecimal totalAmount,String recipientName,String recipientPhone,
            String addressLine,String houseNumber,String area,String landmark,String pincode,String deliveryInstructions,
            LocalDate deliveryDate,DeliverySlot deliverySlot,Instant createdAt,List<OrderItemResponse> items,
            List<StatusEvent> statusHistory,String deliveryOtp,DriverLocationResponse driverLocation,String idempotencyKey){}
    public record OrderStatusRequest(@NotNull OrderStatus status,@Size(max=300) String reason){}
    public record CancelRequest(@Size(max=300) String reason){}
    public record DeliveryCodeResponse(String deliveryOtp){}
    public record AssignDriverRequest(@NotNull Long driverUserId){}
    public record DriverCreateRequest(@NotBlank @Size(max=120) String fullName,@NotBlank @Email @Size(max=254) String email,
            @NotBlank @Pattern(regexp="^[0-9+() -]{7,20}$") String phoneNumber,@NotBlank @Size(min=12,max=72) String password){}
    public record DriverResponse(Long userId,String fullName,String email,String phoneNumber,boolean online,boolean available){}
    public record DriverOrderResponse(Long assignmentId,Long orderId,String orderNumber,AssignmentStatus assignmentStatus,
            OrderStatus orderStatus,String customerName,String customerPhone,String addressLine,String houseNumber,String area,
            String landmark,String pincode,String deliveryInstructions,BigDecimal totalAmount,LocalDate deliveryDate,
            DeliverySlot deliverySlot,List<OrderItemResponse> items){}
    public record AvailabilityRequest(boolean online){}
    public record DriverLocationRequest(@NotNull @DecimalMin("-90.0") @DecimalMax("90.0") BigDecimal latitude,
            @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") BigDecimal longitude){}
    public record DeliverRequest(@NotBlank @Pattern(regexp="^[0-9]{6}$") String otp, boolean cashCollected){}
    public record DeliveryFailRequest(@NotBlank @Size(max=300) String reason){}
    public record ReconcilePaymentRequest(@Size(max=300) String note){}
    public record PaymentReconciliationItem(Long paymentId,Long orderId,String orderNumber,BigDecimal amount,PaymentStatus status,
            Long driverUserId,String driverName,String driverPhone,Instant collectedAt,boolean reconciled,Instant reconciledAt,String note){}
    public record DriverReconciliationSummary(Long driverUserId,String driverName,String driverPhone,
            long unsettledCount,BigDecimal unsettledAmount,long settledCount,BigDecimal settledAmount){}
    public record CodReconciliationReport(BigDecimal totalCollected,BigDecimal totalSettled,BigDecimal totalUnsettled,
            long unpaidDeliveredCount,List<DriverReconciliationSummary> drivers,List<PaymentReconciliationItem> unsettledPayments){}
}
