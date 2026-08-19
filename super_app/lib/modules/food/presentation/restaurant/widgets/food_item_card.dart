import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/presentation/cart/utils/cart_restaurant_guard.dart';
import 'package:superapp_user/modules/food/presentation/cart/viewmodels/cart_viewmodel.dart';
import 'package:superapp_user/modules/food/presentation/cart/widgets/floating_view_cart_bar.dart';
import 'package:superapp_user/design_system/components/media/smart_image.dart';

class FoodItemCard extends ConsumerStatefulWidget {
  final FoodModel food;
  final GlobalKey<FloatingViewCartBarState>? cartBarKey;

  const FoodItemCard({super.key, required this.food, this.cartBarKey});

  @override
  ConsumerState<FoodItemCard> createState() => _FoodItemCardState();
}

class _FoodItemCardState extends ConsumerState<FoodItemCard> {
  final GlobalKey _imageKey = GlobalKey();

  int _quantityFor(CartState cartState) {
    for (final item in cartState.items) {
      if (item.food.id == widget.food.id) return item.quantity;
    }
    return 0;
  }

  String? _cartItemIdFor(CartState cartState) {
    for (final item in cartState.items) {
      if (item.food.id == widget.food.id) return item.id;
    }
    return null;
  }

  Future<void> _handleFirstAdd() async {
    Haptics.light();
    await addFoodToCart(context, ref, widget.food);
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final cartState = ref.watch(cartViewModelProvider);
    final quantity = _quantityFor(cartState);
    final cartItemId = _cartItemIdFor(cartState);

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Image
            ClipRRect(
              key: _imageKey,
              borderRadius: BorderRadius.circular(16),
              child: SmartImage(
                url: food.imageUrl,
                category: ImageCategory.food,
                fit: BoxFit.cover,
                width: 100,
                height: 100,
              ),
            ),
            const SizedBox(width: 16),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    food.description,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${food.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _buildAddButton(context, quantity, cartItemId),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(
    BuildContext context,
    int quantity,
    String? cartItemId,
  ) {
    final hasQty = quantity > 0;
    final primaryColor = Theme.of(context).primaryColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: hasQty ? 76 : 36,
      height: 36,
      padding: hasQty
          ? const EdgeInsets.symmetric(horizontal: 6)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: !hasQty
              ? InkWell(
                  key: const ValueKey('add'),
                  onTap: _handleFirstAdd,
                  borderRadius: BorderRadius.circular(12),
                  child: const Center(
                    child: Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                )
              : Row(
                  key: const ValueKey('stepper'),
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: cartItemId == null
                          ? null
                          : () {
                              Haptics.light();
                              ref
                                  .read(cartViewModelProvider.notifier)
                                  .updateQuantity(cartItemId, quantity - 1);
                            },
                      child: const Icon(
                        Icons.remove,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    Text(
                      '$quantity',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Haptics.light();
                        addFoodToCart(context, ref, widget.food);
                      },
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
