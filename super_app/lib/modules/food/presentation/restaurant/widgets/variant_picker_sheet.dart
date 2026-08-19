import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/data/models/food_variant.dart';
import 'package:superapp_user/modules/food/application/providers/catalog_providers.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';

/// What the user chose in the sheet.
class VariantSelection {
  final FoodVariant? variant;
  final List<FoodAddon> addons;

  const VariantSelection({this.variant, this.addons = const []});

  double get addonTotal => addons.fold(0.0, (sum, a) => sum + a.price);

  /// Delta over the item's base price — what CartItemModel stores as
  /// `selectedVariantPrice` / `selectedAddonsPrice`.
  double variantDelta(double basePrice) =>
      variant == null ? 0.0 : variant!.price - basePrice;

  String get label => [
        if (variant != null) variant!.name,
        ...addons.map((a) => a.name),
      ].join(' • ');
}

/// Variant + add-on picker.
///
/// Shown only when the dish actually has choices — a single-price item with no
/// restaurant add-ons goes straight into the cart, so this never adds a tap
/// where the backend offers nothing to pick.
class VariantPickerSheet extends ConsumerStatefulWidget {
  final FoodModel food;

  const VariantPickerSheet({super.key, required this.food});

  /// Returns null if the user dismissed the sheet.
  static Future<VariantSelection?> show(BuildContext context, FoodModel food) {
    return showModalBottomSheet<VariantSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VariantPickerSheet(food: food),
    );
  }

  /// True when there is something for the user to choose. Callers use this to
  /// decide between showing the sheet and adding directly.
  static bool needsSelection(FoodModel food, List<FoodAddon> addons) =>
      food.variants.isNotEmpty || addons.isNotEmpty;

  @override
  ConsumerState<VariantPickerSheet> createState() => _VariantPickerSheetState();
}

class _VariantPickerSheetState extends ConsumerState<VariantPickerSheet> {
  FoodVariant? _variant;
  final Set<String> _addonIds = {};

  @override
  void initState() {
    super.initState();
    // Preselect the cheapest size so there is always a valid choice.
    final variants = widget.food.variants;
    if (variants.isNotEmpty) {
      _variant = variants.reduce((a, b) => a.price <= b.price ? a : b);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final addons = ref.watch(restaurantAddonsProvider(widget.food.restaurantId)).value ??
        const <FoodAddon>[];
    final selected = addons.where((a) => _addonIds.contains(a.id)).toList();
    final basePrice = _variant?.price ?? widget.food.price;
    final total = basePrice + selected.fold(0.0, (sum, a) => sum + a.price);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.food.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: secondaryColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (widget.food.variants.isNotEmpty) ...[
                  _sectionTitle('Choose a size', textColor, required: true),
                  ...widget.food.variants.map(
                    (v) => _variantTile(v, textColor, secondaryColor),
                  ),
                  const SizedBox(height: 8),
                ],
                if (addons.isNotEmpty) ...[
                  _sectionTitle('Add extras', textColor),
                  ...addons.map((a) => _addonTile(a, textColor, secondaryColor)),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Haptics.light();
                  Navigator.pop(
                    context,
                    VariantSelection(variant: _variant, addons: selected),
                  );
                },
                child: Text(
                  'Add item • ₹${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, Color color, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
          ),
          if (required) ...[
            const SizedBox(width: 6),
            Text(
              'Required',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _variantTile(FoodVariant v, Color textColor, Color secondaryColor) {
    final isSelected = _variant?.id == v.id;
    return InkWell(
      onTap: () {
        Haptics.light();
        setState(() => _variant = v);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primary : secondaryColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                v.name,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            if (v.hasDiscount) ...[
              Text(
                '₹${v.otherPrice!.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryColor,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              '₹${v.price.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addonTile(FoodAddon a, Color textColor, Color secondaryColor) {
    final isSelected = _addonIds.contains(a.id);
    return InkWell(
      onTap: () {
        Haptics.light();
        setState(() {
          if (isSelected) {
            _addonIds.remove(a.id);
          } else {
            _addonIds.add(a.id);
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              color: isSelected ? AppColors.primary : secondaryColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.name,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  if (a.description.isNotEmpty)
                    Text(
                      a.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: secondaryColor),
                    ),
                ],
              ),
            ),
            Text(
              '+₹${a.price.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
