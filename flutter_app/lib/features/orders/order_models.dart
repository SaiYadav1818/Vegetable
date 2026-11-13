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
  final String? houseNumber, landmark, deliveryInstructions, deliveryOtp, idempotencyKey;
  final DateTime deliveryDate, createdAt;
  final List<OrderItem> items;
  final OrderLocation? driverLocation;
  final List<OrderStatusEvent> statusHistory;
  bool get canCancel => status == 'PLACED';
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
