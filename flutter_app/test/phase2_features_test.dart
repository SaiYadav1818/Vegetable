import 'package:flutter_test/flutter_test.dart';
import 'package:freshbasket/features/orders/order_models.dart';

void main() {
  group('Phase 2 Models & Features Tests', () {
    test('ShopSettings parses and serializes correctly', () {
      final json = {
        'id': 1,
        'shopName': 'FreshBasket Neighborhood Mart',
        'contactPhone': '+91 98765 43210',
        'shopAddress': '12/4 Green Avenue, Bangalore',
        'openingTime': '06:30',
        'closingTime': '21:30',
        'openToday': true,
        'minOrderValue': 100.0,
        'deliveryCharge': 30.0,
        'freeDeliveryThreshold': 500.0,
        'announcementBanner': 'Fresh morning harvest!',
      };

      final settings = ShopSettings.fromJson(json);
      expect(settings.shopName, 'FreshBasket Neighborhood Mart');
      expect(settings.openToday, isTrue);
      expect(settings.freeDeliveryThreshold, 500.0);

      final map = settings.toJson();
      expect(map['shopName'], 'FreshBasket Neighborhood Mart');
      expect(map['openToday'], isTrue);
    });

    test('CustomerAddress parses and serializes correctly', () {
      final json = {
        'id': 10,
        'label': 'Home',
        'recipientName': 'Sai Yadav',
        'recipientPhone': '9876543210',
        'addressLine': '402 Green Towers',
        'houseNumber': '402',
        'area': 'Indiranagar',
        'landmark': 'Near Metro',
        'pincode': '560038',
        'isDefault': true,
        'createdAt': '2026-11-16T10:00:00Z',
      };

      final addr = CustomerAddress.fromJson(json);
      expect(addr.id, 10);
      expect(addr.label, 'Home');
      expect(addr.isDefault, isTrue);
      expect(addr.pincode, '560038');

      final map = addr.toJson();
      expect(map['area'], 'Indiranagar');
      expect(map['recipientPhone'], '9876543210');
    });

    test('AnalyticsOverview parses correctly', () {
      final json = {
        'revenue': {
          'totalRevenue': 15000.50,
          'todayRevenue': 3200.00,
          'thisWeekRevenue': 12000.00,
          'averageOrderValue': 450.00,
        },
        'orders': {
          'totalOrders': 45,
          'completedOrders': 38,
          'activeOrders': 5,
          'cancelledOrders': 2,
          'failedOrders': 0,
        },
        'topSellingVegetables': [
          {
            'productId': 1,
            'productName': 'Tomato',
            'quantitySold': 50.5,
            'totalRevenue': 2020.0,
          }
        ],
        'driverFleet': {
          'totalDrivers': 4,
          'onlineDrivers': 3,
          'availableDrivers': 2,
          'deliveriesCompleted': 38,
          'codCollected': 14500.0,
          'codPendingReconciliation': 2500.0,
        }
      };

      final analytics = AnalyticsOverview.fromJson(json);
      expect(analytics.revenue.todayRevenue, 3200.00);
      expect(analytics.orders.completedOrders, 38);
      expect(analytics.topSellingVegetables.length, 1);
      expect(analytics.topSellingVegetables.first.productName, 'Tomato');
      expect(analytics.driverFleet.onlineDrivers, 3);
    });

    test('OrderRecord canReorder and cancellationReason logic', () {
      final orderDelivered = OrderRecord(
        id: 1,
        orderNumber: 'FB-001',
        status: 'DELIVERED',
        paymentStatus: 'PAID',
        subtotal: 100,
        deliveryCharge: 30,
        totalAmount: 130,
        recipientName: 'Sai',
        recipientPhone: '9876543210',
        addressLine: 'Avenue',
        area: 'Indiranagar',
        pincode: '560038',
        deliveryDate: DateTime.now(),
        deliverySlot: 'MORNING',
        createdAt: DateTime.now(),
        items: [],
      );

      expect(orderDelivered.canReorder, isTrue);
      expect(orderDelivered.canCancel, isFalse);

      final orderCancelled = OrderRecord(
        id: 2,
        orderNumber: 'FB-002',
        status: 'CANCELLED',
        paymentStatus: 'PENDING',
        subtotal: 100,
        deliveryCharge: 30,
        totalAmount: 130,
        recipientName: 'Sai',
        recipientPhone: '9876543210',
        addressLine: 'Avenue',
        area: 'Indiranagar',
        pincode: '560038',
        deliveryDate: DateTime.now(),
        deliverySlot: 'MORNING',
        createdAt: DateTime.now(),
        items: [],
        cancellationReason: 'Customer changed mind',
      );

      expect(orderCancelled.canReorder, isTrue);
      expect(orderCancelled.canCancel, isFalse);
      expect(orderCancelled.cancellationReason, 'Customer changed mind');
    });
  });
}
