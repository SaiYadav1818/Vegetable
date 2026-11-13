import 'package:flutter_test/flutter_test.dart';
import 'package:freshbasket/features/catalog/catalog_models.dart';
import 'package:freshbasket/features/customer/customer_cart.dart';
import 'package:freshbasket/features/orders/order_models.dart';

class FakeCartGateway implements CartGateway {
  final Map<int, CartLine> items = {};
  int _next = 1;
  CartSnapshot _snapshot() => CartSnapshot(
      items: items.values.toList(),
      subtotal: items.values.fold<num>(0, (sum, line) => sum + line.lineTotal));
  CartLine _line(int productId, num quantity, {int? id}) => CartLine(
      id: id ?? _next++,
      productId: productId,
      name: 'Potato',
      unit: 'KG',
      price: 30,
      quantity: quantity,
      stock: 2,
      lineTotal: 30 * quantity,
      available: true);
  @override
  Future<CartSnapshot> getCart() async => _snapshot();
  @override
  Future<CartSnapshot> addItem(int productId, {num quantity = 1}) async {
    final existing =
        items.values.where((e) => e.productId == productId).firstOrNull;
    final line = _line(productId, (existing?.quantity ?? 0) + quantity,
        id: existing?.id);
    items[productId] = line;
    return _snapshot();
  }

  @override
  Future<CartSnapshot> updateItem(int itemId, num quantity) async {
    final old = items.values.firstWhere((e) => e.id == itemId);
    items[old.productId] = _line(old.productId, quantity, id: itemId);
    return _snapshot();
  }

  @override
  Future<CartSnapshot> removeItem(int itemId) async {
    items.removeWhere((_, line) => line.id == itemId);
    return _snapshot();
  }
}

void main() {
  test('server-backed cart updates quantities and enforces stock', () async {
    final gateway = FakeCartGateway();
    final cart = CustomerCart(gateway);
    await cart.load();
    final product = Product(
        id: 1,
        name: 'Potato',
        categoryId: 2,
        categoryName: 'Root',
        price: 30,
        unit: 'KG',
        stock: 2,
        minimumStock: 1,
        active: true,
        available: true);
    await cart.add(product);
    await cart.increment(cart.lines.single);
    expect(cart.itemCount, 2);
    expect(cart.subtotal, 60);
    await expectLater(cart.increment(cart.lines.single), throwsStateError);
    await cart.decrement(cart.lines.single);
    expect(cart.itemCount, 1);
    await cart.decrement(cart.lines.single);
    expect(cart.lines, isEmpty);
    cart.dispose();
  });
}
