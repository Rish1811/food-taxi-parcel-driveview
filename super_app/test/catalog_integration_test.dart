import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_user/core/error/failures.dart';
import 'package:superapp_user/core/network/api_client.dart';
import 'package:superapp_user/core/storage/token_storage.dart';
import 'package:superapp_user/modules/food/api/datasources/address_remote_datasource.dart';
import 'package:superapp_user/modules/food/api/datasources/auth_remote_datasource.dart';
import 'package:superapp_user/modules/food/api/datasources/catalog_remote_datasource.dart';
import 'package:superapp_user/modules/food/api/datasources/order_remote_datasource.dart';
import 'package:superapp_user/shared/address/data/address_model.dart';
import 'package:superapp_user/modules/food/data/models/cart_item_model.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';

/// Phase 2 contract tests against the live backend: zone → catalog → menu →
/// cart → /calculate.
///
/// Run: flutter test test/catalog_integration_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = <String, String>{};
  setUpAll(() {
    HttpOverrides.global = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        switch (call.method) {
          case 'write':
            store[call.arguments['key'] as String] = call.arguments['value'] as String;
            return null;
          case 'read':
            return store[call.arguments['key'] as String];
          case 'delete':
            store.remove(call.arguments['key'] as String);
            return null;
          case 'readAll':
            return store;
          case 'deleteAll':
            store.clear();
            return null;
        }
        return null;
      },
    );
  });

  late ApiClient client;
  late CatalogRemoteDataSource catalog;

  // Authenticated once for the whole suite. Calling verify-otp twice inside the
  // same second produces a byte-identical JWT (same `iat`), which the backend's
  // unique index on food_refresh_tokens.token rejects with E11000.
  late ApiClient authedClient;
  late TokenStorage authedTokens;

  setUpAll(() async {
    authedTokens = TokenStorage();
    authedClient = ApiClient(tokens: authedTokens);
    final auth = AuthRemoteDataSource(authedClient);
    final otp = await auth.requestOtp('9999999998');
    final session = await auth.verifyOtp(phone: '9999999998', otp: otp!);
    await authedTokens.save(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
  });

  setUp(() {
    client = ApiClient(tokens: TokenStorage());
    catalog = CatalogRemoteDataSource(client);
  });

  // Indore — the seeded service area.
  const lat = 22.7282081;
  const lng = 75.88436;

  test('zone detection returns an in-service zone for a covered point', () async {
    final zone = await catalog.detectZone(lat: lat, lng: lng);
    expect(zone.isInService, isTrue, reason: 'seeded Indore point should be in service');
    expect(zone.zoneId, isNotNull);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('out-of-coverage is a 200 with OUT_OF_SERVICE, not an error', () async {
    // Mid-Atlantic — definitively outside any zone.
    final zone = await catalog.detectZone(lat: 0.0, lng: -30.0);
    expect(zone.isInService, isFalse);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('home catalog: banners, categories and restaurants all parse', () async {
    final banners = await catalog.getHeroBannerImages();
    final categories = await catalog.getCategories();
    final restaurants = await catalog.getRestaurants(limit: 10);

    expect(banners, isNotEmpty);
    expect(banners.every((b) => b.startsWith('http')), isTrue, reason: 'media must resolve absolute');

    expect(categories, isNotEmpty);
    expect(categories.first.name, isNotEmpty);

    expect(restaurants, isNotEmpty);
    // Guards the two-shape restaurant payload: name must fall back to
    // restaurantName, and profileImage may be a string or { url }.
    expect(restaurants.every((r) => r.name.isNotEmpty), isTrue);
    expect(restaurants.every((r) => r.id.isNotEmpty), isTrue);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('restaurant detail + menu resolve for a seeded restaurant', () async {
    final restaurants = await catalog.getRestaurants(limit: 20);
    final foods = await catalog.getPublicFoods(limit: 50);
    expect(foods, isNotEmpty, reason: 'seeded dish feed should not be empty');

    // Pick a restaurant that actually has menu items.
    final withMenu = foods.first.restaurantId;
    expect(restaurants.any((r) => r.id.isNotEmpty), isTrue);

    final detail = await catalog.getRestaurantById(withMenu);
    expect(detail, isNotNull);
    expect(detail!.name, isNotEmpty);

    final menu = await catalog.getRestaurantMenu(withMenu);
    expect(menu, isNotEmpty, reason: 'restaurant $withMenu should expose menu items');
    expect(menu.every((m) => m.restaurantId == withMenu), isTrue,
        reason: 'menu items must carry their restaurant id for cart/checkout');
    expect(menu.every((m) => m.name.isNotEmpty), isTrue);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('unified search returns restaurant-shaped results', () async {
    final results = await catalog.search('poha');
    expect(results, isNotEmpty);
    expect(results.first.name, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('checkout: /calculate is the source of truth for the bill', () async {
    // A real saved address, since delivery fee depends on it.
    final addresses = AddressRemoteDataSource(authedClient);
    final address = await addresses.addAddress(const AddressModel(
      id: '',
      title: 'Home',
      fullAddress: '',
      type: 'Home',
      street: '17/C Palasia',
      city: 'Indore',
      state: 'Madhya Pradesh',
      zipCode: '452001',
      contactPhone: '9999999998',
      latitude: lat,
      longitude: lng,
    ));
    expect(address.id, isNotEmpty);

    // Cart built from a real menu item.
    final foods = await catalog.getPublicFoods(limit: 50);
    final food = foods.first;
    final cart = [CartItemModel(id: 'line-1', food: food, quantity: 2)];

    final orders = OrderRemoteDataSource(authedClient);
    try {
      final calc = await orders.calculate(
        items: cart,
        restaurantId: food.restaurantId,
        deliveryAddressId: address.id,
      );

      // The server resolves items authoritatively and owns every figure.
      expect(calc.items, isNotEmpty);
      expect(calc.pricing.subtotal, food.price * 2,
          reason: 'server subtotal must match qty x menu price');
      expect(calc.pricing.total,
          greaterThanOrEqualTo(calc.pricing.subtotal - calc.pricing.discount));
      expect(calc.pricing.currency, 'INR');
      // Nothing was applied, so no coupon should be reported as landed.
      expect(calc.pricing.hasCouponApplied, isFalse);
      // raw is what gets echoed into POST /orders — it must survive intact.
      expect(calc.pricing.raw['total'], isNotNull);
    } on ValidationFailure catch (f) {
      // /calculate enforces opening hours, so outside them this is the correct
      // contract response — not a client defect.
      expect(f.message.toLowerCase(), contains('closed'),
          reason: 'the only acceptable rejection here is the closed-restaurant one');
    } finally {
      await addresses.deleteAddress(address.id);
    }
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('a rejected coupon reports appliedCoupon: null, not a discount', () async {
    final foods = await catalog.getPublicFoods(limit: 10);
    final food = foods.first;

    try {
      final calc = await OrderRemoteDataSource(authedClient).calculate(
        items: [CartItemModel(id: 'l1', food: food, quantity: 1)],
        restaurantId: food.restaurantId,
        couponCode: 'DEFINITELY_NOT_A_REAL_COUPON',
      );

      // couponCode is echoed back regardless — appliedCoupon is the real signal.
      expect(calc.pricing.hasCouponApplied, isFalse);
      expect(calc.pricing.discount, 0);
    } on ValidationFailure catch (f) {
      expect(f.message.toLowerCase(), contains('closed'));
    }
  }, timeout: const Timeout(Duration(seconds: 90)));
}

/// Unused import guard — keeps FoodModel referenced for the analyzer when the
/// cart construction above changes shape.
// ignore: unused_element
FoodModel? _typeAnchor;
