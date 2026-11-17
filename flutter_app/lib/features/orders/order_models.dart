class CartLine {
  const CartLine(
      {required this.id,
      required this.productId,
      required this.name,
      required this.unit,
      required this.price,
      required this.quantity,
      required this.stock,
      required this.lineTotal,
      required this.available,
      this.imageUrl});
  final int id;
  final int productId;
  final String name;
  final String unit;
  final num price;
  final num quantity;
  final num stock;
  final num lineTotal;
  final bool available;
  final String? imageUrl;
  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
      id: json['id'] as int,
      productId: json['productId'] as int,
      name: json['name'] as String,
      unit: json['unit'] as String,
      price: json['price'] as num,
      quantity: json['quantity'] as num,
      stock: json['stock'] as num,
      lineTotal: json['lineTotal'] as num,
      available: json['available'] as bool,
      imageUrl: json['imageUrl'] as String?);
}

class CartSnapshot {
  const CartSnapshot({required this.items, required this.subtotal});
  final List<CartLine> items;
  final num subtotal;
  int get itemCount =>
      items.fold<int>(0, (sum, item) => sum + item.quantity.ceil());
  factory CartSnapshot.fromJson(Map<String, dynamic> json) => CartSnapshot(
      items: ((json['items'] as List<dynamic>?) ?? const [])
          .map((e) => CartLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: json['subtotal'] as num);
}

class OrderItem {
  const OrderItem(
      {required this.name,
      required this.unit,
      required this.quantity,
      required this.unitPrice,
      required this.lineTotal});
  final String name, unit;
  final num quantity, unitPrice, lineTotal;
  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
      name: json['name'] as String,
      unit: json['unit'] as String,
      quantity: json['quantity'] as num,
      unitPrice: json['unitPrice'] as num,
      lineTotal: json['lineTotal'] as num);
}

class OrderLocation {
  const OrderLocation(this.latitude, this.longitude, this.updatedAt);
  final num latitude, longitude;
  final DateTime updatedAt;
  factory OrderLocation.fromJson(Map<String, dynamic> json) => OrderLocation(
      json['latitude'] as num,
      json['longitude'] as num,
      DateTime.parse(json['updatedAt'] as String));
}

class OrderStatusEvent {
  const OrderStatusEvent(
      {this.fromStatus,
      required this.toStatus,
      this.reason,
      required this.createdAt});
  final String? fromStatus;
  final String toStatus;
  final String? reason;
  final DateTime createdAt;
  factory OrderStatusEvent.fromJson(Map<String, dynamic> json) =>
      OrderStatusEvent(
        fromStatus: json['fromStatus'] as String?,
        toStatus: json['toStatus'] as String,
        reason: json['reason'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class OrderRecord {
  const OrderRecord(
      {required this.id,
      required this.orderNumber,
      required this.status,
      required this.paymentStatus,
      required this.subtotal,
      required this.deliveryCharge,
      required this.totalAmount,
      required this.recipientName,
      required this.recipientPhone,
      required this.addressLine,
      required this.area,
      required this.pincode,
      required this.deliveryDate,
      required this.deliverySlot,
      required this.createdAt,
      required this.items,
      this.houseNumber,
      this.landmark,
      this.deliveryInstructions,
      this.deliveryOtp,
      this.driverLocation,
      this.idempotencyKey,
      this.cancellationReason,
      this.statusHistory = const []});
  final int id;
  final String orderNumber,
      status,
      paymentStatus,
      recipientName,
      recipientPhone,
      addressLine,
      area,
      pincode,
      deliverySlot;
  final num subtotal, deliveryCharge, totalAmount;
  final String? houseNumber, landmark, deliveryInstructions, deliveryOtp, idempotencyKey, cancellationReason;
  final DateTime deliveryDate, createdAt;
  final List<OrderItem> items;
  final OrderLocation? driverLocation;
  final List<OrderStatusEvent> statusHistory;
  bool get canCancel => status == 'PLACED';
  bool get canReorder => status == 'DELIVERED' || status == 'CANCELLED';
  factory OrderRecord.fromJson(Map<String, dynamic> json) => OrderRecord(
      id: json['id'] as int,
      orderNumber: json['orderNumber'] as String,
      status: json['status'] as String,
      paymentStatus: json['paymentStatus'] as String,
      subtotal: json['subtotal'] as num,
      deliveryCharge: json['deliveryCharge'] as num,
      totalAmount: json['totalAmount'] as num,
      recipientName: json['recipientName'] as String,
      recipientPhone: json['recipientPhone'] as String,
      addressLine: json['addressLine'] as String,
      area: json['area'] as String,
      pincode: json['pincode'] as String,
      deliveryDate: DateTime.parse(json['deliveryDate'] as String),
      deliverySlot: json['deliverySlot'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: ((json['items'] as List<dynamic>?) ?? const [])
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      houseNumber: json['houseNumber'] as String?,
      landmark: json['landmark'] as String?,
      deliveryInstructions: json['deliveryInstructions'] as String?,
      deliveryOtp: json['deliveryOtp'] as String?,
      idempotencyKey: json['idempotencyKey'] as String?,
      cancellationReason: json['cancellationReason'] as String?,
      driverLocation: json['driverLocation'] == null
          ? null
          : OrderLocation.fromJson(
              json['driverLocation'] as Map<String, dynamic>),
      statusHistory: ((json['statusHistory'] as List<dynamic>?) ?? const [])
          .map((e) => OrderStatusEvent.fromJson(e as Map<String, dynamic>))
          .toList());
}

class DriverOrder {
  const DriverOrder(
      {required this.assignmentId,
      required this.orderId,
      required this.orderNumber,
      required this.assignmentStatus,
      required this.orderStatus,
      required this.customerName,
      required this.customerPhone,
      required this.addressLine,
      required this.area,
      required this.pincode,
      required this.totalAmount,
      required this.deliveryDate,
      required this.deliverySlot,
      required this.items,
      this.houseNumber,
      this.landmark,
      this.deliveryInstructions});
  final int assignmentId, orderId;
  final String orderNumber,
      assignmentStatus,
      orderStatus,
      customerName,
      customerPhone,
      addressLine,
      area,
      pincode,
      deliverySlot;
  final num totalAmount;
  final DateTime deliveryDate;
  final List<OrderItem> items;
  final String? houseNumber, landmark, deliveryInstructions;
  factory DriverOrder.fromJson(Map<String, dynamic> json) => DriverOrder(
      assignmentId: json['assignmentId'] as int,
      orderId: json['orderId'] as int,
      orderNumber: json['orderNumber'] as String,
      assignmentStatus: json['assignmentStatus'] as String,
      orderStatus: json['orderStatus'] as String,
      customerName: json['customerName'] as String,
      customerPhone: json['customerPhone'] as String,
      addressLine: json['addressLine'] as String,
      area: json['area'] as String,
      pincode: json['pincode'] as String,
      totalAmount: json['totalAmount'] as num,
      deliveryDate: DateTime.parse(json['deliveryDate'] as String),
      deliverySlot: json['deliverySlot'] as String,
      items: ((json['items'] as List<dynamic>?) ?? const [])
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      houseNumber: json['houseNumber'] as String?,
      landmark: json['landmark'] as String?,
      deliveryInstructions: json['deliveryInstructions'] as String?);
}

class PaymentReconciliationItem {
  const PaymentReconciliationItem({
    required this.paymentId,
    required this.orderId,
    required this.orderNumber,
    required this.amount,
    required this.status,
    this.driverUserId,
    this.driverName,
    this.driverPhone,
    this.collectedAt,
    required this.reconciled,
    this.reconciledAt,
    this.note,
  });
  final int paymentId, orderId;
  final String orderNumber, status;
  final num amount;
  final int? driverUserId;
  final String? driverName, driverPhone, note;
  final DateTime? collectedAt, reconciledAt;
  final bool reconciled;

  factory PaymentReconciliationItem.fromJson(Map<String, dynamic> json) => PaymentReconciliationItem(
    paymentId: json['paymentId'] as int,
    orderId: json['orderId'] as int,
    orderNumber: json['orderNumber'] as String,
    amount: json['amount'] as num,
    status: json['status'] as String,
    driverUserId: json['driverUserId'] as int?,
    driverName: json['driverName'] as String?,
    driverPhone: json['driverPhone'] as String?,
    collectedAt: json['collectedAt'] == null ? null : DateTime.parse(json['collectedAt'] as String),
    reconciled: json['reconciled'] as bool? ?? false,
    reconciledAt: json['reconciledAt'] == null ? null : DateTime.parse(json['reconciledAt'] as String),
    note: json['note'] as String?,
  );
}

class DriverReconciliationSummary {
  const DriverReconciliationSummary({
    required this.driverUserId,
    required this.driverName,
    required this.driverPhone,
    required this.unsettledCount,
    required this.unsettledAmount,
    required this.settledCount,
    required this.settledAmount,
  });
  final int driverUserId;
  final String driverName, driverPhone;
  final int unsettledCount, settledCount;
  final num unsettledAmount, settledAmount;

  factory DriverReconciliationSummary.fromJson(Map<String, dynamic> json) => DriverReconciliationSummary(
    driverUserId: json['driverUserId'] as int,
    driverName: json['driverName'] as String,
    driverPhone: json['driverPhone'] as String,
    unsettledCount: json['unsettledCount'] as int,
    unsettledAmount: json['unsettledAmount'] as num,
    settledCount: json['settledCount'] as int,
    settledAmount: json['settledAmount'] as num,
  );
}

class CodReconciliationReport {
  const CodReconciliationReport({
    required this.totalCollected,
    required this.totalSettled,
    required this.totalUnsettled,
    required this.unpaidDeliveredCount,
    required this.drivers,
    required this.unsettledPayments,
  });
  final num totalCollected, totalSettled, totalUnsettled;
  final int unpaidDeliveredCount;
  final List<DriverReconciliationSummary> drivers;
  final List<PaymentReconciliationItem> unsettledPayments;

  factory CodReconciliationReport.fromJson(Map<String, dynamic> json) => CodReconciliationReport(
    totalCollected: json['totalCollected'] as num,
    totalSettled: json['totalSettled'] as num,
    totalUnsettled: json['totalUnsettled'] as num,
    unpaidDeliveredCount: json['unpaidDeliveredCount'] as int,
    drivers: ((json['drivers'] as List<dynamic>?) ?? const [])
        .map((e) => DriverReconciliationSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
    unsettledPayments: ((json['unsettledPayments'] as List<dynamic>?) ?? const [])
        .map((e) => PaymentReconciliationItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class CustomerAddress {
  const CustomerAddress({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.recipientPhone,
    required this.addressLine,
    required this.area,
    required this.pincode,
    required this.isDefault,
    this.houseNumber,
    this.landmark,
    this.createdAt,
  });
  final int id;
  final String label, recipientName, recipientPhone, addressLine, area, pincode;
  final String? houseNumber, landmark;
  final bool isDefault;
  final DateTime? createdAt;

  factory CustomerAddress.fromJson(Map<String, dynamic> json) => CustomerAddress(
    id: json['id'] as int,
    label: json['label'] as String? ?? 'Home',
    recipientName: json['recipientName'] as String,
    recipientPhone: json['recipientPhone'] as String,
    addressLine: json['addressLine'] as String,
    area: json['area'] as String,
    pincode: json['pincode'] as String,
    isDefault: json['isDefault'] as bool? ?? false,
    houseNumber: json['houseNumber'] as String?,
    landmark: json['landmark'] as String?,
    createdAt: json['createdAt'] == null ? null : DateTime.tryParse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    'recipientName': recipientName,
    'recipientPhone': recipientPhone,
    'addressLine': addressLine,
    'houseNumber': houseNumber,
    'area': area,
    'landmark': landmark,
    'pincode': pincode,
    'isDefault': isDefault,
  };
}

class ShopSettings {
  const ShopSettings({
    required this.id,
    required this.shopName,
    required this.contactPhone,
    required this.shopAddress,
    required this.openingTime,
    required this.closingTime,
    required this.openToday,
    required this.minOrderValue,
    required this.deliveryCharge,
    required this.freeDeliveryThreshold,
    this.announcementBanner,
  });
  final int id;
  final String shopName, contactPhone, shopAddress, openingTime, closingTime;
  final bool openToday;
  final num minOrderValue, deliveryCharge, freeDeliveryThreshold;
  final String? announcementBanner;

  factory ShopSettings.fromJson(Map<String, dynamic> json) => ShopSettings(
    id: json['id'] as int? ?? 1,
    shopName: json['shopName'] as String? ?? 'FreshBasket',
    contactPhone: json['contactPhone'] as String? ?? '',
    shopAddress: json['shopAddress'] as String? ?? '',
    openingTime: json['openingTime'] as String? ?? '06:30',
    closingTime: json['closingTime'] as String? ?? '21:30',
    openToday: json['openToday'] as bool? ?? true,
    minOrderValue: json['minOrderValue'] as num? ?? 100,
    deliveryCharge: json['deliveryCharge'] as num? ?? 30,
    freeDeliveryThreshold: json['freeDeliveryThreshold'] as num? ?? 500,
    announcementBanner: json['announcementBanner'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'shopName': shopName,
    'contactPhone': contactPhone,
    'shopAddress': shopAddress,
    'openingTime': openingTime,
    'closingTime': closingTime,
    'openToday': openToday,
    'minOrderValue': minOrderValue,
    'deliveryCharge': deliveryCharge,
    'freeDeliveryThreshold': freeDeliveryThreshold,
    'announcementBanner': announcementBanner,
  };
}

class RevenueMetrics {
  const RevenueMetrics({
    required this.totalRevenue,
    required this.todayRevenue,
    required this.thisWeekRevenue,
    required this.averageOrderValue,
  });
  final num totalRevenue, todayRevenue, thisWeekRevenue, averageOrderValue;

  factory RevenueMetrics.fromJson(Map<String, dynamic> json) => RevenueMetrics(
    totalRevenue: json['totalRevenue'] as num? ?? 0,
    todayRevenue: json['todayRevenue'] as num? ?? 0,
    thisWeekRevenue: json['thisWeekRevenue'] as num? ?? 0,
    averageOrderValue: json['averageOrderValue'] as num? ?? 0,
  );
}

class OrderMetrics {
  const OrderMetrics({
    required this.totalOrders,
    required this.completedOrders,
    required this.activeOrders,
    required this.cancelledOrders,
    required this.failedOrders,
  });
  final int totalOrders, completedOrders, activeOrders, cancelledOrders, failedOrders;

  factory OrderMetrics.fromJson(Map<String, dynamic> json) => OrderMetrics(
    totalOrders: json['totalOrders'] as int? ?? 0,
    completedOrders: json['completedOrders'] as int? ?? 0,
    activeOrders: json['activeOrders'] as int? ?? 0,
    cancelledOrders: json['cancelledOrders'] as int? ?? 0,
    failedOrders: json['failedOrders'] as int? ?? 0,
  );
}

class TopProductMetric {
  const TopProductMetric({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.totalRevenue,
  });
  final int productId;
  final String productName;
  final num quantitySold, totalRevenue;

  factory TopProductMetric.fromJson(Map<String, dynamic> json) => TopProductMetric(
    productId: json['productId'] as int,
    productName: json['productName'] as String,
    quantitySold: json['quantitySold'] as num? ?? 0,
    totalRevenue: json['totalRevenue'] as num? ?? 0,
  );
}

class DriverFleetMetric {
  const DriverFleetMetric({
    required this.totalDrivers,
    required this.onlineDrivers,
    required this.availableDrivers,
    required this.deliveriesCompleted,
    required this.codCollected,
    required this.codPendingReconciliation,
  });
  final int totalDrivers, onlineDrivers, availableDrivers, deliveriesCompleted;
  final num codCollected, codPendingReconciliation;

  factory DriverFleetMetric.fromJson(Map<String, dynamic> json) => DriverFleetMetric(
    totalDrivers: json['totalDrivers'] as int? ?? 0,
    onlineDrivers: json['onlineDrivers'] as int? ?? 0,
    availableDrivers: json['availableDrivers'] as int? ?? 0,
    deliveriesCompleted: json['deliveriesCompleted'] as int? ?? 0,
    codCollected: json['codCollected'] as num? ?? 0,
    codPendingReconciliation: json['codPendingReconciliation'] as num? ?? 0,
  );
}

class AnalyticsOverview {
  const AnalyticsOverview({
    required this.revenue,
    required this.orders,
    required this.topSellingVegetables,
    required this.driverFleet,
  });
  final RevenueMetrics revenue;
  final OrderMetrics orders;
  final List<TopProductMetric> topSellingVegetables;
  final DriverFleetMetric driverFleet;

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) => AnalyticsOverview(
    revenue: RevenueMetrics.fromJson(json['revenue'] as Map<String, dynamic>? ?? {}),
    orders: OrderMetrics.fromJson(json['orders'] as Map<String, dynamic>? ?? {}),
    topSellingVegetables: ((json['topSellingVegetables'] as List<dynamic>?) ?? const [])
        .map((e) => TopProductMetric.fromJson(e as Map<String, dynamic>))
        .toList(),
    driverFleet: DriverFleetMetric.fromJson(json['driverFleet'] as Map<String, dynamic>? ?? {}),
  );
}

class ReorderItemDetail {
  const ReorderItemDetail({
    required this.productId,
    required this.productName,
    required this.requestedQuantity,
    required this.addedQuantity,
    required this.outOfStock,
  });
  final int productId;
  final String productName;
  final num requestedQuantity, addedQuantity;
  final bool outOfStock;

  factory ReorderItemDetail.fromJson(Map<String, dynamic> json) => ReorderItemDetail(
    productId: json['productId'] as int,
    productName: json['productName'] as String,
    requestedQuantity: json['requestedQuantity'] as num,
    addedQuantity: json['addedQuantity'] as num,
    outOfStock: json['outOfStock'] as bool? ?? false,
  );
}

class ReorderResponse {
  const ReorderResponse({
    required this.itemsAdded,
    required this.itemsUnavailable,
    required this.cart,
    required this.details,
  });
  final int itemsAdded, itemsUnavailable;
  final CartSnapshot cart;
  final List<ReorderItemDetail> details;

  factory ReorderResponse.fromJson(Map<String, dynamic> json) => ReorderResponse(
    itemsAdded: json['itemsAdded'] as int? ?? 0,
    itemsUnavailable: json['itemsUnavailable'] as int? ?? 0,
    cart: CartSnapshot.fromJson(json['cart'] as Map<String, dynamic>),
    details: ((json['details'] as List<dynamic>?) ?? const [])
        .map((e) => ReorderItemDetail.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
