package in.freshbasket.analytics;

import java.math.BigDecimal;
import java.util.List;

public final class AnalyticsDtos {
    private AnalyticsDtos() {}

    public record RevenueMetrics(
            BigDecimal totalRevenue,
            BigDecimal todayRevenue,
            BigDecimal thisWeekRevenue,
            BigDecimal averageOrderValue
    ) {}

    public record OrderMetrics(
            long totalOrders,
            long completedOrders,
            long activeOrders,
            long cancelledOrders,
            long failedOrders
    ) {}

    public record TopProductMetric(
            Long productId,
            String productName,
            BigDecimal quantitySold,
            BigDecimal totalRevenue
    ) {}

    public record DriverFleetMetric(
            long totalDrivers,
            long onlineDrivers,
            long availableDrivers,
            long deliveriesCompleted,
            BigDecimal codCollected,
            BigDecimal codPendingReconciliation
    ) {}

    public record AnalyticsOverviewResponse(
            RevenueMetrics revenue,
            OrderMetrics orders,
            List<TopProductMetric> topSellingVegetables,
            DriverFleetMetric driverFleet
    ) {}
}
