import 'package:flutter_test/flutter_test.dart';
import 'package:leadx/shared/models/order.dart';

void main() {
  group('Product model and API parsing', () {
    test('Product.fromJson parses full payload with string decimals', () {
      final json = {
        'id': 10,
        'name': 'Annual Premium Suite',
        'price': '1499.50',
        'minimum_closing_price': '1200.00',
        'duration': '1y',
        'duration_label': '1 Year',
        'api_key_required': '1',
        'status': 'active',
      };

      final product = Product.fromJson(json);

      expect(product.id, 10);
      expect(product.name, 'Annual Premium Suite');
      expect(product.price, 1499.50);
      expect(product.minimumClosingPrice, 1200.00);
      expect(product.duration, '1y');
      expect(product.durationLabel, '1 Year');
      expect(product.apiKeyRequired, isTrue);
      expect(product.status, 'active');
    });

    test('Product.fromJson handles missing optional fields safely', () {
      final json = {
        'id': '25',
        'name': 'Basic Plan',
        'price': 499,
        'duration': '6m',
      };

      final product = Product.fromJson(json);

      expect(product.id, 25);
      expect(product.name, 'Basic Plan');
      expect(product.price, 499.0);
      expect(product.minimumClosingPrice, 0.0);
      expect(product.duration, '6m');
      expect(product.durationLabel, isNull);
      expect(product.apiKeyRequired, isFalse);
      expect(product.status, 'active');
    });

    test('Product equality works based on id', () {
      final p1 = Product(
        id: 5,
        name: 'CRM Pro',
        price: 999,
        duration: '1y',
      );
      final p2 = Product(
        id: 5,
        name: 'CRM Pro Updated',
        price: 1099,
        duration: '1y',
      );
      final p3 = Product(
        id: 6,
        name: 'CRM Pro',
        price: 999,
        duration: '1y',
      );

      expect(p1 == p2, isTrue);
      expect(p1.hashCode, p2.hashCode);
      expect(p1 == p3, isFalse);
    });

    test('Parses backend products payload with "products" or "data" keys', () {
      final apiResponseWithProductsKey = {
        'products': [
          {
            'id': 1,
            'name': 'Enterprise',
            'price': 2500.00,
            'duration': '1y',
            'duration_label': '1 Year',
          },
          {
            'id': 2,
            'name': 'Inactive Legacy',
            'price': 500.00,
            'duration': '1m',
            'status': 'inactive',
          }
        ]
      };

      final dynamic raw = apiResponseWithProductsKey['data'] ??
          apiResponseWithProductsKey['products'];
      final List<dynamic> list = raw is List ? raw : const [];

      final products = list
          .whereType<Map>()
          .where((e) {
            final status = e['status']?.toString().toLowerCase();
            return status == null || status.isEmpty || status == 'active';
          })
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      expect(products.length, 1);
      expect(products.first.id, 1);
      expect(products.first.name, 'Enterprise');
      expect(products.first.price, 2500.0);
      expect(products.first.status, 'active');
    });
  });
}
