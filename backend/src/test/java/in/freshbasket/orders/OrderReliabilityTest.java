package in.freshbasket.orders;

import in.freshbasket.catalog.*;
import in.freshbasket.notifications.BusinessNotificationPublisher;
import in.freshbasket.user.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class OrderReliabilityTest {
    private final UserRepository users = mock(UserRepository.class);
    private final CartRepository carts = mock(CartRepository.class);
    private final CartItemRepository cartItems = mock(CartItemRepository.class);
    private final OrderRepository orders = mock(OrderRepository.class);
    private final OrderItemRepository orderItems = mock(OrderItemRepository.class);
    private final OrderHistoryRepository history = mock(OrderHistoryRepository.class);
    private final PaymentRepository payments = mock(PaymentRepository.class);
    private final DeliveryOtpRepository otps = mock(DeliveryOtpRepository.class);
    private final DriverAssignmentRepository assignments = mock(DriverAssignmentRepository.class);
    private final DriverLocationRepository locations = mock(DriverLocationRepository.class);
    private final DriverProfileRepository drivers = mock(DriverProfileRepository.class);
    private final ProductRepository products = mock(ProductRepository.class);
    private final InventoryRepository inventory = mock(InventoryRepository.class);
    private final InventoryTransactionRepository inventoryTransactions = mock(InventoryTransactionRepository.class);
    private final BusinessNotificationPublisher notifications = mock(BusinessNotificationPublisher.class);
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

    private OrderService orderService;
    private DeliveryService deliveryService;
    private AppUser customerUser;
    private AppUser adminUser;
    private AppUser driverUser;
    private DriverProfile driverProfile;

    @BeforeEach
    void setUp() {
        orderService = new OrderService(users, carts, cartItems, orders, orderItems, history, payments, otps, assignments,
                locations, products, inventory, inventoryTransactions, notifications, encoder, BigDecimal.ZERO, BigDecimal.valueOf(30));
        deliveryService = new DeliveryService(users, drivers, assignments, locations, otps, orderItems, payments, encoder, orderService, notifications);

        customerUser = new AppUser("customer@example.com", "hash", "Customer One", "9876543210", Role.CUSTOMER);
        ReflectionTestUtils.setField(customerUser, "id", 1L);
        adminUser = new AppUser("admin@example.com", "hash", "Admin Shop", "9876543211", Role.ADMIN);
        ReflectionTestUtils.setField(adminUser, "id", 2L);
        driverUser = new AppUser("driver@example.com", "hash", "Driver Ramesh", "9876543212", Role.DRIVER);
        ReflectionTestUtils.setField(driverUser, "id", 3L);
        driverProfile = new DriverProfile(driverUser);
        driverProfile.setOnline(true);
        driverProfile.setAvailable(true);

        when(users.findByEmail("customer@example.com")).thenReturn(Optional.of(customerUser));
        when(users.findByEmail("admin@example.com")).thenReturn(Optional.of(adminUser));
        when(users.findByEmail("driver@example.com")).thenReturn(Optional.of(driverUser));
    }

    @Test
    void checkoutWithExistingIdempotencyKeyReturnsExistingOrderWithoutRededucting() {
        String key = "test-idempotency-key-12345";
        CustomerOrder existingOrder = new CustomerOrder("FB-123456789012", customerUser, BigDecimal.valueOf(100), BigDecimal.valueOf(30),
                BigDecimal.valueOf(130), "Recipient", "9876543210", "Main St", "12", "Central", "Near Bank", "560001",
                "Leave at door", LocalDate.now(), DeliverySlot.MORNING, null, null);
        ReflectionTestUtils.setField(existingOrder, "id", 100L);
        existingOrder.setIdempotencyKey(key);

        when(orders.findByCustomer_IdAndIdempotencyKey(1L, key)).thenReturn(Optional.of(existingOrder));
        when(orderItems.findByOrder_IdOrderById(100L)).thenReturn(List.of());
        when(history.findByOrder_IdOrderByCreatedAtAsc(100L)).thenReturn(List.of());
        when(assignments.findFirstByOrder_IdAndStatusIn(eq(100L), any())).thenReturn(Optional.empty());

        var checkoutReq = new OrderDtos.CheckoutRequest(key, BigDecimal.valueOf(100), "Recipient", "9876543210",
                "Main St", "12", "Central", "Near Bank", "560001", "Leave at door", LocalDate.now(), DeliverySlot.MORNING, null, null);

        var result = orderService.place("customer@example.com", checkoutReq);

        assertNotNull(result);
        assertEquals("FB-123456789012", result.orderNumber());
        assertEquals(key, result.idempotencyKey());
        verify(carts, never()).findByCustomer_Id(any());
        verify(inventory, never()).findLockedByProductId(any());
    }

    @Test
    void driverDeliveryFailureUpdatesStatusToDeliveryFailedWithoutRestoringStock() {
        CustomerOrder order = new CustomerOrder("FB-123456789012", customerUser, BigDecimal.valueOf(100), BigDecimal.valueOf(30),
                BigDecimal.valueOf(130), "Recipient", "9876543210", "Main St", "12", "Central", "Near Bank", "560001",
                "Leave at door", LocalDate.now(), DeliverySlot.MORNING, null, null);
        ReflectionTestUtils.setField(order, "id", 100L);
        order.status(OrderStatus.OUT_FOR_DELIVERY);

        DriverAssignment assignment = new DriverAssignment(order, driverProfile, adminUser);
        ReflectionTestUtils.setField(assignment, "id", 50L);
        assignment.accept();
        assignment.pickup();

        when(assignments.findLockedByOrderIdAndStatusIn(eq(100L), any())).thenReturn(Optional.of(assignment));
        when(orders.findLocked(100L)).thenReturn(Optional.of(order));
        when(orderItems.findByOrder_IdOrderById(100L)).thenReturn(List.of());

        var failReq = new OrderDtos.DeliveryFailRequest("Customer not at home, phone switched off");
        var result = deliveryService.fail(100L, "driver@example.com", failReq);

        assertNotNull(result);
        assertEquals(AssignmentStatus.FAILED, assignment.getStatus());
        assertEquals("Customer not at home, phone switched off", assignment.getFailureReason());
        assertEquals(OrderStatus.DELIVERY_FAILED, order.getStatus());
        assertTrue(driverProfile.isAvailable());
        verify(inventory, never()).findLockedByProductId(any());
        verify(inventoryTransactions, never()).save(any());
    }

    @Test
    void adminCanReassignDriverWhenOrderInDeliveryFailedState() {
        CustomerOrder order = new CustomerOrder("FB-123456789012", customerUser, BigDecimal.valueOf(100), BigDecimal.valueOf(30),
                BigDecimal.valueOf(130), "Recipient", "9876543210", "Main St", "12", "Central", "Near Bank", "560001",
                "Leave at door", LocalDate.now(), DeliverySlot.MORNING, null, null);
        ReflectionTestUtils.setField(order, "id", 100L);
        order.status(OrderStatus.DELIVERY_FAILED);

        AppUser driverTwo = new AppUser("driver2@example.com", "hash", "Driver Suresh", "9876543213", Role.DRIVER);
        ReflectionTestUtils.setField(driverTwo, "id", 4L);
        DriverProfile driverProfileTwo = new DriverProfile(driverTwo);
        driverProfileTwo.setOnline(true);
        driverProfileTwo.setAvailable(true);

        when(orders.findLocked(100L)).thenReturn(Optional.of(order));
        when(assignments.findFirstByOrder_IdAndStatusIn(eq(100L), any())).thenReturn(Optional.empty());
        when(drivers.findLocked(4L)).thenReturn(Optional.of(driverProfileTwo));
        when(assignments.save(any(DriverAssignment.class))).thenAnswer(i -> i.getArgument(0));
        when(orderItems.findByOrder_IdOrderById(100L)).thenReturn(List.of());
        when(history.findByOrder_IdOrderByCreatedAtAsc(100L)).thenReturn(List.of());

        var response = deliveryService.assign(100L, 4L, "admin@example.com");

        assertNotNull(response);
        assertEquals(OrderStatus.DRIVER_ASSIGNED, order.getStatus());
        assertFalse(driverProfileTwo.isAvailable());
        verify(assignments).save(any(DriverAssignment.class));
    }

    @Test
    void deliverWithCashCollectedMarksPaymentPaidAndReconciliationTracksIt() {
        CustomerOrder order = new CustomerOrder("FB-123456789012", customerUser, BigDecimal.valueOf(100), BigDecimal.valueOf(30),
                BigDecimal.valueOf(130), "Recipient", "9876543210", "Main St", "12", "Central", "Near Bank", "560001",
                "Leave at door", LocalDate.now(), DeliverySlot.MORNING, null, null);
        ReflectionTestUtils.setField(order, "id", 100L);
        order.status(OrderStatus.OUT_FOR_DELIVERY);

        DriverAssignment assignment = new DriverAssignment(order, driverProfile, adminUser);
        ReflectionTestUtils.setField(assignment, "id", 50L);
        assignment.accept();
        assignment.pickup();

        String rawOtp = "123456";
        DeliveryOtp otp = new DeliveryOtp(order, encoder.encode(rawOtp), Instant.now().plusSeconds(3600));

        Payment payment = new Payment(order, BigDecimal.valueOf(130));
        ReflectionTestUtils.setField(payment, "id", 200L);

        when(assignments.findLockedByOrderIdAndStatusIn(eq(100L), any())).thenReturn(Optional.of(assignment));
        when(orders.findLocked(100L)).thenReturn(Optional.of(order));
        when(otps.findLocked(100L)).thenReturn(Optional.of(otp));
        when(payments.findByOrder_Id(100L)).thenReturn(Optional.of(payment));
        when(orderItems.findByOrder_IdOrderById(100L)).thenReturn(List.of());
        when(history.findByOrder_IdOrderByCreatedAtAsc(100L)).thenReturn(List.of());

        var deliverReq = new OrderDtos.DeliverRequest("123456", true);
        var response = deliveryService.deliver(100L, "driver@example.com", deliverReq);

        assertNotNull(response);
        assertEquals(OrderStatus.DELIVERED, order.getStatus());
        assertEquals(PaymentStatus.PAID, order.getPaymentStatus());
        assertEquals(PaymentStatus.PAID, payment.getStatus());
        assertEquals(driverUser, payment.getCollectedBy());
        assertFalse(payment.isReconciled());

        // Now test Admin reconciliation of this payment
        when(payments.findById(200L)).thenReturn(Optional.of(payment));
        var reconReq = new OrderDtos.ReconcilePaymentRequest("Cash received at counter");
        var reconItem = deliveryService.reconcilePayment(200L, reconReq, "admin@example.com");

        assertTrue(reconItem.reconciled());
        assertEquals("Cash received at counter", reconItem.note());
        assertTrue(payment.isReconciled());
    }

    @Test
    void deliverWithoutCashCollectedKeepsPaymentPendingAndDecoupledFromDeliveredStatus() {
        CustomerOrder order = new CustomerOrder("FB-123456789012", customerUser, BigDecimal.valueOf(100), BigDecimal.valueOf(30),
                BigDecimal.valueOf(130), "Recipient", "9876543210", "Main St", "12", "Central", "Near Bank", "560001",
                "Leave at door", LocalDate.now(), DeliverySlot.MORNING, null, null);
        ReflectionTestUtils.setField(order, "id", 100L);
        order.status(OrderStatus.OUT_FOR_DELIVERY);

        DriverAssignment assignment = new DriverAssignment(order, driverProfile, adminUser);
        ReflectionTestUtils.setField(assignment, "id", 50L);
        assignment.accept();
        assignment.pickup();

        String rawOtp = "123456";
        DeliveryOtp otp = new DeliveryOtp(order, encoder.encode(rawOtp), Instant.now().plusSeconds(3600));

        Payment payment = new Payment(order, BigDecimal.valueOf(130));
        ReflectionTestUtils.setField(payment, "id", 200L);

        when(assignments.findLockedByOrderIdAndStatusIn(eq(100L), any())).thenReturn(Optional.of(assignment));
        when(orders.findLocked(100L)).thenReturn(Optional.of(order));
        when(otps.findLocked(100L)).thenReturn(Optional.of(otp));
        when(payments.findByOrder_Id(100L)).thenReturn(Optional.of(payment));
        when(orderItems.findByOrder_IdOrderById(100L)).thenReturn(List.of());
        when(history.findByOrder_IdOrderByCreatedAtAsc(100L)).thenReturn(List.of());

        // Cash NOT collected (customer promised UPI or store credit)
        var deliverReq = new OrderDtos.DeliverRequest("123456", false);
        var response = deliveryService.deliver(100L, "driver@example.com", deliverReq);

        assertNotNull(response);
        assertEquals(OrderStatus.DELIVERED, order.getStatus());
        assertEquals(PaymentStatus.PENDING, order.getPaymentStatus());
        assertEquals(PaymentStatus.FAILED, payment.getStatus());
        assertNull(payment.getCollectedBy());
    }
}
