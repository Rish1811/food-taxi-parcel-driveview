import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_user/modules/food/data/models/cart_item_model.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/data/models/food_variant.dart';
import 'package:superapp_user/modules/food/api/datasources/order_remote_datasource.dart';

/// Fixture tests for variants and add-ons.
///
/// The live backend has no seeded variants or add-ons (every `variants[]` is
/// empty and `/addons` returns `[]`), so these are pinned to the documented
/// schema rather than to live data.
void main() {
  group('FoodVariant parsing', () {
    test('reads the canonical `variants` key', () {
      final variants = FoodVariant.listFrom({
        'variants': [
          {'name': 'Half', 'price': 160, 'otherPrice': 200},
          {'name': 'Full', 'price': 260, 'otherPrice': 320},
        ],
      });

      expect(variants, hasLength(2));
      expect(variants.first.name, 'Half');
      expect(variants.first.price, 160);
      expect(variants.first.hasDiscount, isTrue);
    });

    test('falls back to the legacy `variations` key', () {
      final variants = FoodVariant.listFrom({
        'variants': <dynamic>[],
        'variations': [
          {'name': 'Regular', 'price': 99},
        ],
      });

      expect(variants, hasLength(1));
      expect(variants.single.name, 'Regular');
      expect(variants.single.hasDiscount, isFalse);
    });

    test('prefers `variants` when both are populated, never merges them', () {
      final variants = FoodVariant.listFrom({
        'variants': [
          {'name': 'Full', 'price': 260},
        ],
        'variations': [
          {'name': 'Full', 'price': 260},
        ],
      });

      expect(variants, hasLength(1), reason: 'duplicate legacy key must not double up');
    });

    test('drops nameless entries and handles a missing key', () {
      expect(FoodVariant.listFrom({}), isEmpty);
      expect(
        FoodVariant.listFrom({
          'variants': [
            {'price': 100},
          ],
        }),
        isEmpty,
      );
    });

    test('FoodModel picks variants up off a menu item', () {
      final food = FoodModel.fromApi({
        '_id': 'item-1',
        'restaurantId': 'rest-1',
        'name': 'Paneer Tikka',
        'price': 260,
        'foodType': 'Veg',
        'variants': [
          {'name': 'Full', 'price': 260},
        ],
      });

      expect(food.variants, hasLength(1));
      expect(food.isVeg, isTrue);
    });
  });

  group('FoodAddon parsing', () {
    test('maps the published add-on projection', () {
      final addon = FoodAddon.fromApi({
        '_id': 'addon-1',
        'name': 'Extra Cheese',
        'description': 'Loads of it',
        'price': 40,
        'foodType': 'veg',
      });

      expect(addon.id, 'addon-1');
      expect(addon.price, 40);
      expect(addon.isVeg, isTrue);
    });

    test('backend foodType enum is lowercase `non-veg`', () {
      final addon = FoodAddon.fromApi({
        '_id': 'a2',
        'name': 'Chicken Chunks',
        'price': 60,
        'foodType': 'non-veg',
      });
      expect(addon.isVeg, isFalse);
    });
  });

  group('cart pricing with variants and add-ons', () {
    final food = FoodModel.fromApi({
      '_id': 'item-1',
      'restaurantId': 'rest-1',
      'name': 'Pizza',
      'price': 200,
      'variants': [
        {'name': 'Large', 'price': 320},
      ],
    });

    test('unit price = base + variant delta + add-ons', () {
      final line = CartItemModel(
        id: 'l1',
        food: food,
        quantity: 2,
        selectedVariant: 'Large',
        // Delta over base: 320 - 200.
        selectedVariantPrice: 120,
        selectedAddons: const ['addon-1'],
        selectedAddonsPrice: 40,
      );

      expect(line.unitPrice, 360);
      expect(line.totalPrice, 720);
    });

    test('order payload sends the selection-inclusive unit price', () {
      final line = CartItemModel(
        id: 'l1',
        food: food,
        quantity: 1,
        selectedVariant: 'Large',
        selectedVariantPrice: 120,
        selectedAddons: const ['addon-1'],
        selectedAddonsPrice: 40,
      );

      final payload = OrderRemoteDataSource.itemPayload(line);

      // The server bills off `price`, so it must include the choices.
      expect(payload['price'], 360);
      expect(payload['variantName'], 'Large');
      expect(payload['variantPrice'], 320, reason: 'absolute variant price, not the delta');
      expect(payload['addons'], ['addon-1']);
      expect(payload['quantity'], 1);
    });

    test('plain item sends no variant fields', () {
      final payload = OrderRemoteDataSource.itemPayload(
        CartItemModel(id: 'l2', food: food, quantity: 1),
      );

      expect(payload.containsKey('variantName'), isFalse);
      expect(payload.containsKey('addons'), isFalse);
      expect(payload['price'], 200);
    });
  });
}
