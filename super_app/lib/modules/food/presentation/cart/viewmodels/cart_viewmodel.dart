import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/modules/food/application/providers/order_providers.dart';
import 'package:superapp_user/shared/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:superapp_user/modules/food/data/models/cart_item_model.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:uuid/uuid.dart';

class CartState {
  final List<CartItemModel> items;

  const CartState({this.items = const []});

  /// The one restaurant every line in the cart belongs to — `null` when the
  /// cart is empty. The app only ever allows a single restaurant per cart.
  String? get restaurantId =>
      items.isEmpty ? null : items.first.food.restaurantId;

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      items.fold(0, (sum, item) => sum + item.totalPrice);

  // Sum of (original menu price - current price) across the cart — the
  // "you saved ₹X already" figure, driven by each FoodModel's real
  // originalPrice rather than a fabricated coupon amount.
  double get totalSavings => items.fold(0.0, (sum, item) {
    final original = item.food.originalPrice;
    if (original == null || original <= item.food.price) return sum;
    return sum + (original - item.food.price) * item.quantity;
  });

  /// Fees and the payable total are server-owned — see
  /// POST /food/orders/calculate via CheckoutViewModel. The cart only knows
  /// the line-item subtotal, which is what the floating bar previews.
  double get total => subtotal;

  CartState copyWith({List<CartItemModel>? items}) {
    return CartState(items: items ?? this.items);
  }
}

final cartViewModelProvider = NotifierProvider<CartViewModel, CartState>(() {
  return CartViewModel();
});

class CartViewModel extends Notifier<CartState> {
  CartViewModel({List<CartItemModel>? initialItems, bool syncEnabled = true})
    : _initialItems = initialItems,
      _syncEnabled = syncEnabled;

  final _uuid = const Uuid();
  final List<CartItemModel>? _initialItems;
  final bool _syncEnabled;

  @override
  CartState build() {
    return CartState(items: _initialItems ?? const []);
  }

  void addItem(
    FoodModel food, {
    int quantity = 1,
    String? specialInstructions,
    String? selectedVariant,
    double selectedVariantPrice = 0.0,
    List<String> selectedAddons = const [],
    double selectedAddonsPrice = 0.0,
  }) {
    // If the food item has variants and no variant was explicitly selected,
    // default to the first size variant so backend variant validation passes.
    final effectiveVariant =
        (selectedVariant == null || selectedVariant.isEmpty) &&
                food.variants.isNotEmpty
            ? food.variants.first.name
            : selectedVariant;
    final effectiveVariantPrice =
        (selectedVariant == null || selectedVariant.isEmpty) &&
                food.variants.isNotEmpty
            ? (food.variants.first.price - food.price)
            : selectedVariantPrice;

    // Lines merge only when the dish AND the chosen variant/add-ons match, so
    // a large pizza with cheese stays separate from a plain regular one.
    final existingIndex = state.items.indexWhere(
      (item) =>
          item.food.id == food.id &&
          item.selectedVariant == effectiveVariant &&
          _sameAddons(item.selectedAddons, selectedAddons),
    );

    if (existingIndex >= 0) {
      // Update existing
      final currentItem = state.items[existingIndex];
      final updatedItem = currentItem.copyWith(
        quantity: currentItem.quantity + quantity,
        specialInstructions:
            specialInstructions ?? currentItem.specialInstructions,
      );
      final newItems = List<CartItemModel>.from(state.items);
      newItems[existingIndex] = updatedItem;
      state = state.copyWith(items: newItems);
      _syncToServer();
    } else {
      // Add new
      final newItem = CartItemModel(
        id: _uuid.v4(),
        food: food,
        quantity: quantity,
        specialInstructions: specialInstructions,
        selectedVariant: effectiveVariant,
        selectedVariantPrice: effectiveVariantPrice,
        selectedAddons: selectedAddons,
        selectedAddonsPrice: selectedAddonsPrice,
      );
      state = state.copyWith(items: [...state.items, newItem]);
      _syncToServer();
    }
  }

  /// Re-customizes an existing cart line in place — used when the user reopens
  /// a line already in the cart and changes its variant/add-ons, instead of
  /// [addItem]'s "same dish, different config = new line" merge rule.
  ///
  /// If the new configuration happens to match another existing line, the two
  /// are merged (quantities summed) so the cart never shows the same dish +
  /// variant + add-on combination twice.
  void updateItem(
    String cartItemId, {
    required FoodModel food,
    String? selectedVariant,
    double selectedVariantPrice = 0.0,
    List<String> selectedAddons = const [],
    double selectedAddonsPrice = 0.0,
    String? specialInstructions,
  }) {
    final index = state.items.indexWhere((item) => item.id == cartItemId);
    if (index < 0) return;
    final current = state.items[index];

    final mergeIndex = state.items.indexWhere(
      (item) =>
          item.id != cartItemId &&
          item.food.id == food.id &&
          item.selectedVariant == selectedVariant &&
          _sameAddons(item.selectedAddons, selectedAddons),
    );

    final newItems = List<CartItemModel>.from(state.items);
    if (mergeIndex >= 0) {
      final target = newItems[mergeIndex];
      newItems[mergeIndex] = target.copyWith(
        quantity: target.quantity + current.quantity,
      );
      newItems.removeAt(index);
    } else {
      newItems[index] = CartItemModel(
        id: cartItemId,
        food: food,
        quantity: current.quantity,
        selectedVariant: selectedVariant,
        selectedVariantPrice: selectedVariantPrice,
        selectedAddons: selectedAddons,
        selectedAddonsPrice: selectedAddonsPrice,
        specialInstructions: specialInstructions ?? current.specialInstructions,
      );
    }
    state = state.copyWith(items: newItems);
    _syncToServer();
  }

  /// Order-insensitive add-on comparison, so selection order never splits a line.
  bool _sameAddons(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final x = [...a]..sort();
    final y = [...b]..sort();
    for (var i = 0; i < x.length; i++) {
      if (x[i] != y[i]) return false;
    }
    return true;
  }

  void removeItem(String cartItemId) {
    state = state.copyWith(
      items: state.items.where((item) => item.id != cartItemId).toList(),
    );
    _syncToServer();
  }

  void updateQuantity(String cartItemId, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(cartItemId);
      return;
    }

    final newItems = state.items.map((item) {
      if (item.id == cartItemId) {
        return item.copyWith(quantity: newQuantity);
      }
      return item;
    }).toList();

    state = state.copyWith(items: newItems);

    _syncToServer();
  }

  void clearCart() {
    state = const CartState();
    _syncToServer();
  }

  /// True when [restaurantId] differs from whatever restaurant the cart
  /// already belongs to — the single-restaurant-per-cart rule. An empty
  /// cart never conflicts.
  bool hasRestaurantConflict(String restaurantId) {
    final current = state.restaurantId;
    return current != null && current != restaurantId;
  }

  /// Wipes the cart without a network round-trip — for callers about to
  /// immediately push a full replacement (Replace Cart, Reorder), so the
  /// server only ever sees the final state instead of a fleeting empty one.
  void clearCartSilently() {
    state = const CartState();
  }

  /// Pushes the cart to `PUT /food/user/cart` for cross-device continuity.
  ///
  /// Best-effort and fire-and-forget: checkout sends its own cart to
  /// `/calculate`, so a failed sync must never block the user. No-op for guests.
  void _syncToServer() {
    if (!_syncEnabled) return;
    if (ref.read(authViewModelProvider).value == null) return;
    final items = state.items;
    unawaited(
      ref
          .read(orderRemoteDataSourceProvider)
          .syncCart(
            items: items,
            restaurantId: items.isEmpty ? null : items.first.food.restaurantId,
          )
          .catchError((_) {}),
    );
  }
}
