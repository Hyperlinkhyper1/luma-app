import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/worth_counter/worth_counter_store.dart';

WorthProduct _product({double price = 2, int count = 0}) => WorthProduct(
      id: 'p1',
      name: 'Coffee',
      price: price,
      count: count,
      color: 0xFF7C5AD9,
    );

void main() {
  group('WorthProduct', () {
    test('a €2 product counted 20 times is worth €40', () {
      expect(_product(price: 2, count: 20).total, 40);
    });

    test('an uncounted product contributes nothing', () {
      expect(_product(price: 12.5).total, 0);
    });

    test('cents multiply out correctly', () {
      expect(_product(price: 2.5, count: 3).total, closeTo(7.5, 1e-9));
    });

    test('round-trips through JSON', () {
      final json = _product(price: 1.75, count: 4).toJson();
      final restored = WorthProduct.fromJson(json);
      expect(restored.id, 'p1');
      expect(restored.name, 'Coffee');
      expect(restored.price, 1.75);
      expect(restored.count, 4);
      expect(restored.color, 0xFF7C5AD9);
      expect(restored.total, 7);
    });

    test('a malformed stored entry falls back to safe defaults', () {
      final restored = WorthProduct.fromJson(<String, dynamic>{'name': 'Tea'});
      expect(restored.name, 'Tea');
      expect(restored.price, 0);
      expect(restored.count, 0);
      expect(restored.id, isNotEmpty);
    });
  });
}
