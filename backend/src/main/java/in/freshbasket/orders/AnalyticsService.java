package in.freshbasket.orders;

import in.freshbasket.analytics.AnalyticsDtos;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;

@Service
public class AnalyticsService {
    private final OrderRepository orders;
    private final OrderItemRepository orderItems;
    private final PaymentRepository payments;
    private final DriverProfileRepository drivers;

    public AnalyticsService(OrderRepository orders, OrderItemRepository orderItems,
                            PaymentRepository payments, DriverProfileRepository drivers) {
        this.orders = orders;
        this.orderItems = orderItems;
        this.payments = payments;
        this.drivers = drivers;
    }

    @Transactional(readOnly = true)
    public AnalyticsDtos.AnalyticsOverviewResponse getOverview() {
        long totalOrders = orders.count();
        long completedOrders = orders.countByStatus(OrderStatus.DELIVERED);
        long activeOrders = orders.countByStatusIn(List.of(
                OrderStatus.PLACED, OrderStatus.ACCEPTED, OrderStatus.PREPARING,
                OrderStatus.READY_FOR_PICKUP, OrderStatus.DRIVER_ASSIGNED, OrderStatus.OUT_FOR_DELIVERY
        ));
        long cancelledOrders = orders.countByStatusIn(List.of(OrderStatus.CANCELLED, OrderStatus.REJECTED));
        long failedOrders = orders.countByStatus(OrderStatus.DELIVERY_FAILED);

        AnalyticsDtos.OrderMetrics orderMetrics = new AnalyticsDtos.OrderMetrics(
                totalOrders, completedOrders, activeOrders, cancelledOrders, failedOrders
        );

        BigDecimal totalRevenue = orders.sumTotalAmountByStatus(OrderStatus.DELIVERED);
        if (totalRevenue == null) totalRevenue = BigDecimal.ZERO;
        totalRevenue = totalRevenue.setScale(2, RoundingMode.HALF_UP);

        Instant startOfToday = Instant.now().truncatedTo(ChronoUnit.DAYS);
        BigDecimal todayRevenue = orders.sumTotalAmountByStatusAndCreatedAtAfter(OrderStatus.DELIVERED, startOfToday);
        if (todayRevenue == null) todayRevenue = BigDecimal.ZERO;
        todayRevenue = todayRevenue.setScale(2, RoundingMode.HALF_UP);

        Instant sevenDaysAgo = Instant.now().minus(7, ChronoUnit.DAYS);
        BigDecimal thisWeekRevenue = orders.sumTotalAmountByStatusAndCreatedAtAfter(OrderStatus.DELIVERED, sevenDaysAgo);
        if (thisWeekRevenue == null) thisWeekRevenue = BigDecimal.ZERO;
        thisWeekRevenue = thisWeekRevenue.setScale(2, RoundingMode.HALF_UP);

        BigDecimal aov = completedOrders > 0
                ? totalRevenue.divide(BigDecimal.valueOf(completedOrders), 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP);

        AnalyticsDtos.RevenueMetrics revenueMetrics = new AnalyticsDtos.RevenueMetrics(
                totalRevenue, todayRevenue, thisWeekRevenue, aov
        );

        List<AnalyticsDtos.TopProductMetric> topProducts = new ArrayList<>();
        List<Object[]> rawTop = orderItems.findTopSellingDelivered(PageRequest.of(0, 5));
        for (Object[] row : rawTop) {
            Long prodId = ((Number) row[0]).longValue();
            String prodName = (String) row[1];
            BigDecimal qty = (BigDecimal) row[2];
            BigDecimal rev = (BigDecimal) row[3];
            topProducts.add(new AnalyticsDtos.TopProductMetric(prodId, prodName,
                    qty.setScale(2, RoundingMode.HALF_UP),
                    rev.setScale(2, RoundingMode.HALF_UP)));
        }

        long totalDrivers = drivers.count();
        long onlineDrivers = drivers.countByOnlineTrue();
        long availableDrivers = drivers.countByOnlineTrueAndAvailableTrue();
        BigDecimal codCollected = payments.sumTotalPaid().setScale(2, RoundingMode.HALF_UP);
        BigDecimal codPending = payments.sumUnreconciledPaid().setScale(2, RoundingMode.HALF_UP);

        AnalyticsDtos.DriverFleetMetric driverFleet = new AnalyticsDtos.DriverFleetMetric(
                totalDrivers, onlineDrivers, availableDrivers, completedOrders, codCollected, codPending
        );

        return new AnalyticsDtos.AnalyticsOverviewResponse(
                revenueMetrics, orderMetrics, topProducts, driverFleet
        );
    }
}
