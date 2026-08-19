import 'package:superapp_user/modules/food/data/models/food_model.dart';

class CartItemModel {
  final String id;
  final FoodModel food;
  final int quantity;
  final String? selectedVariant;
  final double selectedVariantPrice;
  final List<String> selectedAddons;
  final double selectedAddonsPrice;
  final String? specialInstructions;

  const CartItemModel({
    required this.id,
    required this.food,
    this.quantity = 1,
    this.selectedVariant,
    this.selectedVariantPrice = 0.0,
    this.selectedAddons = const [],
    this.selectedAddonsPrice = 0.0,
    this.specialInstructions,
  });

  double get unitPrice => food.price + selectedVariantPrice + selectedAddonsPrice;
  double get totalPrice => unitPrice * quantity;

  CartItemModel copyWith({
    String? id,
    FoodModel? food,
    int? quantity,
    String? selectedVariant,
    double? selectedVariantPrice,
    List<String>? selectedAddons,
    double? selectedAddonsPrice,
    String? specialInstructions,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      food: food ?? this.food,
      quantity: quantity ?? this.quantity,
      selectedVariant: selectedVariant ?? this.selectedVariant,
      selectedVariantPrice: selectedVariantPrice ?? this.selectedVariantPrice,
      selectedAddons: selectedAddons ?? this.selectedAddons,
      selectedAddonsPrice: selectedAddonsPrice ?? this.selectedAddonsPrice,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }
}

