import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/data/models/food_variant.dart';
import 'package:superapp_user/modules/food/application/providers/catalog_providers.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/modules/food/presentation/restaurant/widgets/food_detail_sheet.dart';
import 'package:superapp_user/modules/food/presentation/cart/viewmodels/cart_viewmodel.dart';

/// Confirms with the user before wiping their cart for a different
/// restaurant's item — the single-restaurant-per-cart rule every "Add to
/// Cart" entry point in the app funnels through. Returns false when the
/// user cancels; callers must not add anything in that case.
Future<bool> ensureCartRestaurant(
  BuildContext context,
  WidgetRef ref,
  String restaurantId,
) async {
  final notifier = ref.read(cartViewModelProvider.notifier);
  if (!notifier.hasRestaurantConflict(restaurantId)) return true;

  final replace = await showDialog<bool>(
    context: context,
    builder: (_) => const _ReplaceCartDialog(),
  );
  if (replace != true) return false;

  notifier.clearCartSilently();
  return true;
}

/// Single-item convenience over [ensureCartRestaurant] + `addItem` — the
/// path most "Add to Cart" taps in the app should call.
///
/// If a product has variants or add-ons and has not been configured yet,
/// this automatically opens [FoodDetailSheet] with option focus instead of
/// adding a default item directly.
Future<void> addFoodToCart(
  BuildContext context,
  WidgetRef ref,
  FoodModel food, {
  int quantity = 1,
  String? specialInstructions,
  String? selectedVariant,
  double selectedVariantPrice = 0.0,
  List<String> selectedAddons = const [],
  double selectedAddonsPrice = 0.0,
  bool fromBottomSheet = false,
}) async {
  // Check if item has backend variants or add-ons and hasn't been configured yet
  final hasVariants = food.variants.isNotEmpty;
  final addons = ref.read(restaurantAddonsProvider(food.restaurantId)).value ?? const <FoodAddon>[];
  final hasAddons = addons.isNotEmpty;

  final needsSelection = (hasVariants || hasAddons) &&
      selectedVariant == null &&
      selectedAddons.isEmpty &&
      !fromBottomSheet;

  if (needsSelection) {
    await FoodDetailSheet.show(
      context,
      food,
      autoScrollToOptions: true,
    );
    return;
  }

  final allowed = await ensureCartRestaurant(context, ref, food.restaurantId);
  if (!allowed) return;

  var variant = selectedVariant;
  var variantPrice = selectedVariantPrice;
  var addonsList = selectedAddons;
  var addonsPrice = selectedAddonsPrice;

  if (variant == null && food.variants.isNotEmpty) {
    variant = food.variants.first.name;
    variantPrice = food.variants.first.price - food.price;
  }

  ref
      .read(cartViewModelProvider.notifier)
      .addItem(
        food,
        quantity: quantity,
        specialInstructions: specialInstructions,
        selectedVariant: variant,
        selectedVariantPrice: variantPrice,
        selectedAddons: addonsList,
        selectedAddonsPrice: addonsPrice,
      );
}

class _ReplaceCartDialog extends StatelessWidget {
  const _ReplaceCartDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : const Color(0xFF6B7280);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3E8),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Replace Cart?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your cart contains items from another restaurant.\n\n'
              'Would you like to clear your current cart and add items '
              'from this restaurant instead?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: secondaryColor,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color: isDark
                            ? AppColors.borderDark
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: secondaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Replace Cart',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
