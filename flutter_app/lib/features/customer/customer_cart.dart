import 'package:flutter/foundation.dart';
import '../catalog/catalog_models.dart';

class CartLine {
  CartLine({required this.product, this.quantity = 1});
  final Product product;
  int quantity;
  num get lineTotal => product.price * quantity;
}

/// Phase 2 cart presentation state. Checkout and server cart synchronization
/// are wired in Phase 4.
class CustomerCart extends ChangeNotifier {
  final Map<int, CartLine> _lines = {};
  List<CartLine> get lines => List.unmodifiable(_lines.values);
  int get itemCount =>
      _lines.values.fold(0, (sum, line) => sum + line.quantity);
  num get subtotal =>
      _lines.values.fold<num>(0, (sum, line) => sum + line.lineTotal);

  void add(Product product) {
    final line = _lines[product.id];
    if (line == null) {
      _lines[product.id] = CartLine(product: product);
    } else if (line.quantity < product.stock) {
      line.quantity++;
    }
    notifyListeners();
  }

  void increment(int productId) {
    final line = _lines[productId];
    if (line == null || line.quantity >= line.product.stock) return;
    line.quantity++;
    notifyListeners();
  }

  void decrement(int productId) {
    final line = _lines[productId];
    if (line == null) return;
    if (line.quantity <= 1) {
      _lines.remove(productId);
    } else {
      line.quantity--;
    }
    notifyListeners();
  }

  void remove(int productId) {
    _lines.remove(productId);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }
}
