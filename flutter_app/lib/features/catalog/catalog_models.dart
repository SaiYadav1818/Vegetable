class Category {
  const Category({
    required this.id,
    required this.name,
    this.description,
    this.active = true,
  });
  final int id;
  final String name;
  final String? description;
  final bool active;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        active: json['active'] as bool? ?? true,
      );
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.price,
    required this.unit,
    required this.stock,
    required this.minimumStock,
    required this.active,
    required this.available,
    this.description,
    this.imageUrl,
  });
  final int id;
  final String name;
  final String? description;
  final int categoryId;
  final String categoryName;
  final num price;
  final String unit;
  final String? imageUrl;
  final bool active;
  final bool available;
  final num stock;
  final num minimumStock;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        categoryId: json['categoryId'] as int,
        categoryName: json['categoryName'] as String,
        price: json['price'] as num,
        unit: json['unit'] as String,
        imageUrl: json['imageUrl'] as String?,
        active: json['active'] as bool,
        available: json['available'] as bool,
        stock: json['stock'] as num,
        minimumStock: json['minimumStock'] as num,
      );
}

class InventoryTransaction {
  const InventoryTransaction({
    required this.id,
    required this.quantityDelta,
    required this.quantityAfter,
    required this.reason,
    required this.createdAt,
    this.note,
  });
  final int id;
  final num quantityDelta;
  final num quantityAfter;
  final String reason;
  final String? note;
  final DateTime createdAt;

  factory InventoryTransaction.fromJson(Map<String, dynamic> json) =>
      InventoryTransaction(
        id: json['id'] as int,
        quantityDelta: json['quantityDelta'] as num,
        quantityAfter: json['quantityAfter'] as num,
        reason: json['reason'] as String,
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
