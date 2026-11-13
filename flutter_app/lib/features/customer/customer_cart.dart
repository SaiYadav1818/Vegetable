import 'package:flutter/foundation.dart';
import '../catalog/catalog_models.dart';
import '../orders/order_models.dart';

abstract interface class CartGateway {
  Future<CartSnapshot> getCart();
  Future<CartSnapshot> addItem(int productId, {num quantity = 1});
  Future<CartSnapshot> updateItem(int itemId, num quantity);
  Future<CartSnapshot> removeItem(int itemId);
}

/// Server-backed cart state; checkout revalidates every quantity and price.
class CustomerCart extends ChangeNotifier {
  CustomerCart(this._gateway);
  final CartGateway _gateway;
  CartSnapshot _snapshot = const CartSnapshot(items: [], subtotal: 0);
  bool _loading = false;
  String? _error;
  CartSnapshot get snapshot => _snapshot;
  List<CartLine> get lines => _snapshot.items;
  num get itemCount => _snapshot.itemCount;
  num get subtotal => _snapshot.subtotal;
  bool get loading => _loading;
  String? get error => _error;
  num quantityFor(int productId) =>
      _snapshot.items
          .where((l) => l.productId == productId)
          .firstOrNull
          ?.quantity ??
      0;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _snapshot = await _gateway.getCart();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> add(Product product) async {
    final current = quantityFor(product.id);
    if (current + 1 > product.stock)
      throw StateError('Requested quantity exceeds current stock');
    await _update(() => _gateway.addItem(product.id));
  }

  Future<void> increment(CartLine line) async {
    if (line.quantity + 1 > line.stock)
      throw StateError('Requested quantity exceeds current stock');
    await _update(() => _gateway.updateItem(line.id, line.quantity + 1));
  }

  Future<void> decrement(CartLine line) async {
    if (line.quantity <= 1) {
      await _update(() => _gateway.removeItem(line.id));
    } else {
      await _update(() => _gateway.updateItem(line.id, line.quantity - 1));
    }
  }

  Future<void> remove(CartLine line) =>
      _update(() => _gateway.removeItem(line.id));
  Future<void> refresh() => load();
  Future<void> _update(Future<CartSnapshot> Function() action) async {
    _error = null;
    try {
      _snapshot = await action();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
