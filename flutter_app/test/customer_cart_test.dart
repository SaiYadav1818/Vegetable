import 'package:flutter_test/flutter_test.dart';
import 'package:freshbasket/features/catalog/catalog_models.dart';
import 'package:freshbasket/features/customer/customer_cart.dart';

void main() {
  test('cart changes quantities and blocks quantities beyond current stock',
      () {
    final cart = CustomerCart();
    final potato = Product(
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

    cart.add(potato);
    cart.increment(potato.id);
    cart.increment(potato.id);
    expect(cart.itemCount, 2);
    expect(cart.subtotal, 60);

    cart.decrement(potato.id);
    expect(cart.itemCount, 1);
    cart.decrement(potato.id);
    expect(cart.lines, isEmpty);
    cart.dispose();
  });
}
