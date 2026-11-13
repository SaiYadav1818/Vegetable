import 'package:flutter_test/flutter_test.dart';
import 'package:freshbasket/features/catalog/catalog_models.dart';

void main() {
  group('Catalog API models', () {
    test('parses category response', () {
      final category =
          Category.fromJson({'id': 3, 'name': 'Leafy greens', 'active': true});
      expect(category.id, 3);
      expect(category.name, 'Leafy greens');
      expect(category.description, isNull);
    });

    test('parses product price, stock, and unit from API response', () {
      final product = Product.fromJson({
        'id': 12,
        'name': 'Spinach',
        'description': 'Fresh bunch',
        'categoryId': 3,
        'categoryName': 'Leafy greens',
        'price': 24.50,
        'unit': 'BUNCH',
        'imageUrl': null,
        'active': true,
        'available': true,
        'stock': 8.250,
        'minimumStock': 2.000,
      });
      expect(product.id, 12);
      expect(product.price, 24.5);
      expect(product.stock, 8.25);
      expect(product.unit, 'BUNCH');
      expect(product.available, isTrue);
    });
  });
}
