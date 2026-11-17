package in.freshbasket.orders;

import in.freshbasket.catalog.*;
import in.freshbasket.notifications.BusinessNotificationPublisher;
import in.freshbasket.shop.ShopSettings;
import in.freshbasket.shop.ShopSettingsService;
import in.freshbasket.user.AppUser;
import in.freshbasket.user.Role;
import in.freshbasket.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class Phase2EndToEndFeaturesTest {
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
    private final ProductRepository products = mock(ProductRepository.class);
    private final InventoryRepository inventory = mock(InventoryRepository.class);
    private final InventoryTransactionRepository inventoryTransactions = mock(InventoryTransactionRepository.class);
    private final BusinessNotificationPublisher notifications = mock(BusinessNotificationPublisher.class);
    private final ShopSettingsService shopSettingsService = mock(ShopSettingsService.class);
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

    private OrderService orderService;
    private AppUser customerUser;
    private AppUser adminUser;

    @BeforeEach
    void setUp() {
        orderService = new OrderService(users, carts, cartItems, orders, orderItems, history, payments, otps,
                assignments, locations, products, inventory, inventoryTransactions, notifications, encoder,
                BigDecimal.ZERO, BigDecimal.valueOf(30), shopSettingsService);

        customerUser = new AppUser("customer@freshbasket.in", "hash", "Sai Customer", "9876543210", Role.CUSTOMER);
        ReflectionTestUtils.setField(customerUser, "id", 1L);
        when(users.findByEmail("customer@freshbasket.in")).thenReturn(Optional.of(customerUser));

        adminUser = new AppUser("admin@freshbasket.in", "hash", "Admin Shop", "9876543211", Role.ADMIN);
        ReflectionTestUtils.setField(adminUser, "id", 2L);
        when(users.findByEmail("admin@freshbasket.in")).thenReturn(Optional.of(adminUser));

        ShopSettings shopSettings = new ShopSettings("FreshMart", "1234567890", "Shop Address", "06:30", "21:30",
                true, BigDecimal.valueOf(50), BigDecimal.valueOf(30), BigDecimal.valueOf(500), null);
        when(shopSettingsService.getOrCreateSettings()).thenReturn(shopSettings);
        when(shopSettingsService.calculateDeliveryCharge(any())).thenReturn(BigDecimal.valueOf(30));
    }

    @Test
    void customerCancellation_recordsReasonAndRestoresStock() {
        CustomerOrder order = new CustomerOrder("FB-ORDER001", customerUser, BigDecimal.valueOf(200),
                BigDecimal.valueOf(30), BigDecimal.valueOf(230), "Sai", "9876543210", "Avenue Road",
                "10", "Sector 1", "Landmark", "560001", null, LocalDate.now(), DeliverySlot.EVENING, null, null);
        ReflectionTestUtils.setField(order, "id", 10L);

        when(orders.findLocked(10L)).thenReturn(Optional.of(order));

        Category cat = new Category("Vegetables", "Fresh");
        Product p = new Product("Tomato", "Desi", cat, BigDecimal.valueOf(40), ProductUnit.KG, null);
        ReflectionTestUtils.setField(p, "id", 101L);
        when(products.findById(101L)).thenReturn(Optional.of(p));

        Inventory stock = new Inventory(p, BigDecimal.valueOf(5), BigDecimal.valueOf(1));
        when(inventory.findLockedByProductId(101L)).thenReturn(Optional.of(stock));

        OrderItem item = new OrderItem(order, p, BigDecimal.valueOf(2), BigDecimal.valueOf(40));
        when(orderItems.findByOrder_IdOrderById(10L)).thenReturn(List.of(item));

        OrderDtos.OrderResponse res = orderService.cancelMine(10L, "customer@freshbasket.in", "Changed mind about dinner");
        assertEquals(OrderStatus.CANCELLED, res.status());
        assertEquals("Changed mind about dinner", order.getCancellationReason());
        assertEquals(BigDecimal.valueOf(7), stock.getQuantity(), "Stock should be restored by 2 KG");
    }

    @Test
    void adminCancellation_fromReadyForPickup_cancelsDriverAndRestoresStock() {
        CustomerOrder order = new CustomerOrder("FB-ORDER002", customerUser, BigDecimal.valueOf(300),
                BigDecimal.valueOf(30), BigDecimal.valueOf(330), "Sai", "9876543210", "Avenue Road",
                "10", "Sector 1", "Landmark", "560001", null, LocalDate.now(), DeliverySlot.MORNING, null, null);
        ReflectionTestUtils.setField(order, "id", 20L);
        order.status(OrderStatus.READY_FOR_PICKUP);

        when(orders.findLocked(20L)).thenReturn(Optional.of(order));

        Category cat = new Category("Root", "Roots");
        Product p = new Product("Potato", "Fresh", cat, BigDecimal.valueOf(30), ProductUnit.KG, null);
        ReflectionTestUtils.setField(p, "id", 201L);
        when(products.findById(201L)).thenReturn(Optional.of(p));

        Inventory stock = new Inventory(p, BigDecimal.valueOf(10), BigDecimal.valueOf(2));
        when(inventory.findLockedByProductId(201L)).thenReturn(Optional.of(stock));

        OrderItem item = new OrderItem(order, p, BigDecimal.valueOf(5), BigDecimal.valueOf(30));
        when(orderItems.findByOrder_IdOrderById(20L)).thenReturn(List.of(item));

        AppUser driverUser = new AppUser("driver@freshbasket.in", "hash", "Driver 1", "9999999999", Role.DRIVER);
        DriverAssignment assignment = new DriverAssignment(order, new DriverProfile(driverUser), adminUser);
        when(assignments.findFirstByOrder_IdAndStatusIn(eq(20L), any())).thenReturn(Optional.of(assignment));

        OrderDtos.OrderStatusRequest cancelReq = new OrderDtos.OrderStatusRequest(OrderStatus.CANCELLED, "Customer phone call cancellation");
        OrderDtos.OrderResponse res = orderService.adminStatus(20L, cancelReq, "admin@freshbasket.in");

        assertEquals(OrderStatus.CANCELLED, res.status());
        assertEquals(AssignmentStatus.CANCELLED, assignment.getStatus());
        assertEquals("Customer phone call cancellation", order.getCancellationReason());
        assertEquals(BigDecimal.valueOf(15), stock.getQuantity(), "Stock should be restored from 10 to 15 KG");
    }

    @Test
    void reorder_populatesCartWithAvailableItems() {
        CustomerOrder pastOrder = new CustomerOrder("FB-PAST001", customerUser, BigDecimal.valueOf(100),
                BigDecimal.valueOf(30), BigDecimal.valueOf(130), "Sai", "9876543210", "Avenue",
                "10", "Area", "Landmark", "560001", null, LocalDate.now().minusDays(5), DeliverySlot.MORNING, null, null);
        ReflectionTestUtils.setField(pastOrder, "id", 99L);
        when(orders.findById(99L)).thenReturn(Optional.of(pastOrder));

        Cart cart = new Cart(customerUser);
        ReflectionTestUtils.setField(cart, "id", 1L);
        when(carts.findByCustomer_Id(1L)).thenReturn(Optional.of(cart));

        Category cat = new Category("Veggies", "Fresh");
        Product p1 = new Product("Carrot", "Ooty", cat, BigDecimal.valueOf(50), ProductUnit.KG, null);
        ReflectionTestUtils.setField(p1, "id", 301L);
        Product p2 = new Product("Spinach", "Palak", cat, BigDecimal.valueOf(30), ProductUnit.BUNCH, null);
        ReflectionTestUtils.setField(p2, "id", 302L);

        when(products.findById(301L)).thenReturn(Optional.of(p1));
        when(products.findById(302L)).thenReturn(Optional.of(p2));

        // Carrot has stock 5 (sellable 4 with safety buffer 1)
        Inventory stock1 = new Inventory(p1, BigDecimal.valueOf(5), BigDecimal.valueOf(1), BigDecimal.valueOf(1));
        // Spinach has stock 0
        Inventory stock2 = new Inventory(p2, BigDecimal.valueOf(0), BigDecimal.valueOf(1), BigDecimal.ZERO);

        when(inventory.findById(301L)).thenReturn(Optional.of(stock1));
        when(inventory.findById(302L)).thenReturn(Optional.of(stock2));

        OrderItem item1 = new OrderItem(pastOrder, p1, BigDecimal.valueOf(2), BigDecimal.valueOf(50));
        OrderItem item2 = new OrderItem(pastOrder, p2, BigDecimal.valueOf(1), BigDecimal.valueOf(30));
        when(orderItems.findByOrder_IdOrderById(99L)).thenReturn(List.of(item1, item2));
        when(cartItems.findByCart_IdOrderByProduct_Id(1L)).thenReturn(Collections.emptyList());

        OrderDtos.ReorderResponse reorderResponse = orderService.reorder(99L, "customer@freshbasket.in");

        assertNotNull(reorderResponse);
        assertEquals(1, reorderResponse.itemsAdded(), "Carrot should be added to cart");
        assertEquals(1, reorderResponse.itemsUnavailable(), "Spinach is out of stock and should be flagged");
        verify(cartItems).save(any(CartItem.class));
    }
}
