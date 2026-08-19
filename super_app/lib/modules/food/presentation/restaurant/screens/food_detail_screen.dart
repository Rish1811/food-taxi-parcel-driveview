import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/app/routing/back_navigation.dart';
import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/data/models/food_variant.dart';
import 'package:superapp_user/modules/food/application/providers/catalog_providers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:superapp_user/modules/food/data/services/deep_link_service.dart';
import 'package:superapp_user/modules/food/presentation/cart/viewmodels/cart_viewmodel.dart';
import 'package:superapp_user/modules/food/presentation/cart/utils/cart_restaurant_guard.dart';
import 'package:superapp_user/modules/food/presentation/cart/animations/add_to_cart_animation.dart';
import 'package:superapp_user/modules/food/presentation/cart/widgets/floating_view_cart_bar.dart';
import 'package:superapp_user/design_system/components/media/smart_image.dart';
import 'package:superapp_user/modules/food/presentation/favorites/viewmodels/favorites_viewmodel.dart';
import 'package:superapp_user/app/routing/route_names.dart';

class FoodDetailScreen extends ConsumerStatefulWidget {
  final FoodModel food;

  const FoodDetailScreen({super.key, required this.food});

  @override
  ConsumerState<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends ConsumerState<FoodDetailScreen>
    with TickerProviderStateMixin {
  int _currentImageIndex = 0;
  Timer? _carouselTimer;
  bool _isInteracting = false;

  // Customization selections — backed by the dish's real `variants` and the
  // restaurant's real `/addons` (via restaurantAddonsProvider), never by
  // fabricated options that don't affect what's actually charged.
  FoodVariant? _selectedVariant;
  final Set<String> _selectedAddonIds = {};
  int _quantity = 1;

  // Animations
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  late AnimationController _cartBounceController;
  late Animation<double> _cartBounceAnimation;

  // Add-to-cart flight targets: the hero image is the fallback start point
  // (used when there's no thumbnail gallery); otherwise the flight starts
  // from whichever thumbnail is currently selected, matching the compact
  // thumbnail-sized start Home Screen's cards use rather than the full
  // 420px hero banner.
  final GlobalKey _imageKey = GlobalKey();
  late final List<GlobalKey> _thumbKeys;
  final GlobalKey<FloatingViewCartBarState> _cartBarKey =
      GlobalKey<FloatingViewCartBarState>();

  @override
  void initState() {
    super.initState();

    // Pre-select the first real size/portion choice, when the dish has any.
    if (widget.food.variants.isNotEmpty) {
      _selectedVariant = widget.food.variants.first;
    }

    // One key per thumbnail slot (matches maxThumbs in _buildThumbnails).
    _thumbKeys = List.generate(4, (_) => GlobalKey());

    // Auto-scroll carousel every 2 seconds
    if (widget.food.imageGallery.isNotEmpty) {
      _startCarouselTimer();
    }

    // Floating Animation for main image
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    // Cart button bounce animation
    _cartBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _cartBounceAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _cartBounceController, curve: Curves.easeInOut),
    );
  }

  static final Random _random = Random();

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _scheduleNextDetailRotation();
  }

  void _scheduleNextDetailRotation() {
    if (!mounted) return;
    final jitter = _random.nextInt(600) - 300;
    final interval = Duration(milliseconds: (4200 + jitter).clamp(3200, 5500));

    _carouselTimer = Timer(interval, () {
      if (!_isInteracting && mounted && widget.food.imageGallery.isNotEmpty) {
        setState(() {
          _currentImageIndex =
              (_currentImageIndex + 1) % widget.food.imageGallery.length;
        });
      }
      _scheduleNextDetailRotation();
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _floatController.dispose();
    _cartBounceController.dispose();
    super.dispose();
  }

  void _toggleAddon(String addonId) {
    setState(() {
      if (_selectedAddonIds.contains(addonId)) {
        _selectedAddonIds.remove(addonId);
      } else {
        _selectedAddonIds.add(addonId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFFAFAFA);
    final surfaceColor = isDark ? const Color(0xFF1B1B1B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final secondaryTextColor = isDark
        ? const Color(0xFF9E9E9E)
        : const Color(0xFF757575);
    final restaurantAddons =
        ref.watch(restaurantAddonsProvider(widget.food.restaurantId)).value ??
        const <FoodAddon>[];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // 1. Scrollable Content (Bottom layer)
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              // Padding pushes the content down below the fixed header
              // 420 (image height) + 64 (spacing for thumbnails and padding) = 484
              padding: const EdgeInsets.only(top: 484, bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProductInfo(textColor, secondaryTextColor, isDark),
                  if (widget.food.variants.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildServingSize(textColor, surfaceColor, isDark),
                  ],
                  if (restaurantAddons.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildAddExtras(textColor, isDark, restaurantAddons),
                  ],
                ],
              ),
            ),
          ),

          // 2. Fixed Top Section (Image + Curve + Thumbnails)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // Height is 420 (image) + (75/2) thumbnail overflow = 457.5
            height: 457.5,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Solid background to hide scrolling content as it slides up
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 420,
                  child: Container(color: backgroundColor),
                ),

                // Full Bleed Image Background with Curved Bottom
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 420,
                  child: ClipRRect(
                    key: _imageKey,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(60),
                    ),
                    child: _buildImageSection(isDark),
                  ),
                ),

                // Floating Thumbnails (intersecting the bottom curve of the image)
                Positioned(
                  top: 382.5, // 420 - (75 / 2)
                  left: 0,
                  right: 0,
                  child: Center(child: _buildThumbnails(isDark)),
                ),
              ],
            ),
          ),

          // Floating Top Bar (Back & Favorite)
          Positioned(top: 0, left: 0, right: 0, child: _buildTopBar(isDark)),

          // Sticky Bottom Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildStickyBottomBar(
              surfaceColor,
              isDark,
              restaurantAddons,
            ),
          ),

          // Same floating "View Cart" bar as Home Screen, raised clear of
          // the sticky Add to Cart bar below it (~104px tall) instead of
          // the default 24px Home Screen uses with no bar of its own there.
          FloatingViewCartBar(
            key: _cartBarKey,
            bottomOffset: 120.0,
            onTap: () {
              Haptics.light();
              context.go(RouteNames.cart);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () => context.backOr(),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black),
              ),
            ),
            Row(
              children: [
                InkWell(
                  onTap: () {
                    Haptics.light();
                    final text = DeepLinkService.generateProductShareText(
                      productName: widget.food.name,
                      productId: widget.food.id,
                      restaurantId: widget.food.restaurantId,
                    );
                    SharePlus.instance.share(ShareParams(text: text));
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.share_rounded,
                      color: Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Consumer(
                  builder: (context, ref, child) {
                    final isFavorite = ref.watch(
                      favoritesViewModelProvider.select(
                        (s) => s.value?.foodIds.contains(widget.food.id) ?? false,
                      ),
                    );
                    return InkWell(
                      onTap: () {
                        Haptics.light();
                        ref
                            .read(favoritesViewModelProvider.notifier)
                            .toggleFood(widget.food.id, widget.food);
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: const Color(0xFFFF7A00),
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(bool isDark) {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: Hero(
            tag: widget.food.id,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                            child: child,
                          ),
                        );
                      },
                  child: SmartImage(
                    key: ValueKey<int>(_currentImageIndex),
                    url: widget.food.imageGallery.isNotEmpty
                        ? widget.food.imageGallery[_currentImageIndex]
                        : widget.food.imageUrl,
                    category: ImageCategory.food,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                // Dark gradient overlay at the very top for status bar visibility
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.3],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnails(bool isDark) {
    if (widget.food.imageGallery.isEmpty) return const SizedBox.shrink();

    final maxThumbs = 4;
    final displayThumbs = widget.food.imageGallery.take(maxThumbs).toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(displayThumbs.length, (index) {
        final isSelected = _currentImageIndex == index;
        final isLast = index == maxThumbs - 1;
        final remaining = widget.food.imageGallery.length - maxThumbs;

        return GestureDetector(
          onTapDown: (_) => setState(() => _isInteracting = true),
          onTapUp: (_) => setState(() => _isInteracting = false),
          onTapCancel: () => setState(() => _isInteracting = false),
          onTap: () {
            if (isLast && remaining > 0) return;
            setState(() {
              _currentImageIndex = index;
              _isInteracting = true; // Pause auto-scroll briefly
            });
            // Reset interacting flag after a short delay
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) setState(() => _isInteracting = false);
            });
          },
          child: AnimatedContainer(
            key: _thumbKeys[index],
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: isSelected ? 75 : 65,
            height: isSelected ? 75 : 65,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFF7A00)
                    : (isDark ? const Color(0xFF303030) : Colors.white),
                width: isSelected ? 2.5 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SmartImage(
                    url: displayThumbs[index],
                    category: ImageCategory.food,
                    fit: BoxFit.cover,
                  ),
                  if (isLast && remaining > 0)
                    Container(
                      color: Colors.black.withValues(alpha: 0.6),
                      child: Center(
                        child: Text(
                          '+$remaining',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildProductInfo(
    Color textColor,
    Color secondaryTextColor,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.food.name,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${widget.food.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF7A00),
                    ),
                  ),
                  if (widget.food.originalPrice != null)
                    Row(
                      children: [
                        Text(
                          '₹${widget.food.originalPrice!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '-${widget.food.discountPercent}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF4B72),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
          if (widget.food.rating > 0 || widget.food.calories > 0 || widget.food.deliveryTime.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                if (widget.food.rating > 0) ...[
                  _buildInfoBadge(
                    Icons.star_rounded,
                    const Color(0xFFFFC107),
                    '${widget.food.rating} ',
                    widget.food.reviewCount > 0 ? '(${widget.food.reviewCount})' : '',
                    textColor,
                    secondaryTextColor,
                    isDark,
                  ),
                  if (widget.food.calories > 0 || widget.food.deliveryTime.trim().isNotEmpty)
                    const SizedBox(width: 10),
                ],
                if (widget.food.calories > 0) ...[
                  _buildInfoBadge(
                    Icons.local_fire_department_rounded,
                    const Color(0xFFFF4B72),
                    '${widget.food.calories} Kcal',
                    '',
                    textColor,
                    secondaryTextColor,
                    isDark,
                  ),
                  if (widget.food.deliveryTime.trim().isNotEmpty)
                    const SizedBox(width: 10),
                ],
                if (widget.food.deliveryTime.trim().isNotEmpty)
                  _buildInfoBadge(
                    Icons.access_time_rounded,
                    const Color(0xFF4B7BFF),
                    widget.food.deliveryTime,
                    '',
                    textColor,
                    secondaryTextColor,
                    isDark,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text(
            widget.food.description,
            style: TextStyle(
              fontSize: 15,
              color: secondaryTextColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(
    IconData icon,
    Color iconColor,
    String primary,
    String secondary,
    Color textColor,
    Color secondaryColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B1B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF303030) : const Color(0xFFF0F0F0),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 4),
          RichText(
            text: TextSpan(
              text: primary,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: textColor,
              ),
              children: [
                if (secondary.isNotEmpty)
                  TextSpan(
                    text: secondary,
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: secondaryColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServingSize(Color textColor, Color surfaceColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Serving Size',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: widget.food.variants.map((variant) {
              final isSelected = _selectedVariant?.name == variant.name;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedVariant = variant),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark ? surfaceColor : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF7A00)
                            : (isDark
                                  ? const Color(0xFF303030)
                                  : const Color(0xFFEEEEEE)),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        variant.name,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFFFF7A00)
                              : textColor,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAddExtras(Color textColor, bool isDark, List<FoodAddon> addons) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B1B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF303030) : const Color(0xFFF5F5F5),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Extras',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              Text(
                'Customize your order',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF9E9E9E)
                      : const Color(0xFF9E9E9E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: addons.length,
              itemBuilder: (context, index) {
                final addon = addons[index];
                final isSelected = _selectedAddonIds.contains(addon.id);
                return GestureDetector(
                  onTap: () => _toggleAddon(addon.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF242424) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF7A00)
                            : (isDark
                                  ? const Color(0xFF303030)
                                  : const Color(0xFFF0F0F0)),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          color: addon.isVeg
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                          size: 10,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              addon.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                            Text(
                              '+ ₹${addon.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF757575),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          color: isSelected
                              ? const Color(0xFFFF7A00)
                              : const Color(0xFFBDBDBD),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar(
    Color surfaceColor,
    bool isDark,
    List<FoodAddon> addons,
  ) {
    final selectedAddons = addons
        .where((a) => _selectedAddonIds.contains(a.id))
        .toList();
    final selection = FoodSelection(
      variant: _selectedVariant,
      addons: selectedAddons,
    );
    final addonsTotal = selection.addonTotal;
    final unitPrice = selection.unitPrice(widget.food.price);
    final variantDelta = _selectedVariant == null
        ? 0.0
        : _selectedVariant!.price - widget.food.price;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B1B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Quantity Selector
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121212) : const Color(0xFFF5F6F8),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                _buildQuantityButton(Icons.remove, () {
                  Haptics.light();
                  if (_quantity > 1) {
                    setState(() => _quantity--);
                  }
                }, isDark),
                SizedBox(
                  width: 32,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return ScaleTransition(
                              scale: animation,
                              child: child,
                            );
                          },
                      child: Text(
                        '$_quantity',
                        key: ValueKey<int>(_quantity),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
                _buildQuantityButton(Icons.add, () {
                  Haptics.light();
                  setState(() => _quantity++);
                }, isDark),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Add to Cart Button
          Expanded(
            child: ScaleTransition(
              scale: _cartBounceAnimation,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTapDown: (_) => _cartBounceController.forward(),
                  onTapUp: (_) => _cartBounceController.reverse(),
                  onTapCancel: () => _cartBounceController.reverse(),
                  onTap: () async {
                    final allowed = await ensureCartRestaurant(
                      context,
                      ref,
                      widget.food.restaurantId,
                    );
                    if (!allowed || !mounted) return;

                    Haptics.light();
                    // Fly-to-cart animation whose flight target is this
                    // screen's own floating "View Cart" bar; the item is only
                    // added once the flight completes.
                    final hasThumbs = widget.food.imageGallery.isNotEmpty;
                    final startKey = hasThumbs
                        ? _thumbKeys[_currentImageIndex.clamp(
                            0,
                            _thumbKeys.length - 1,
                          )]
                        : _imageKey;
                    final anchorKey = _cartBarKey.currentState?.flightAnchorKey;

                    void addAll() {
                      final cartNotifier = ref.read(
                        cartViewModelProvider.notifier,
                      );
                      for (int i = 0; i < _quantity; i++) {
                        cartNotifier.addItem(
                          widget.food,
                          selectedVariant: _selectedVariant?.name,
                          selectedVariantPrice: variantDelta,
                          selectedAddons: selectedAddons
                              .map((a) => a.id)
                              .toList(),
                          selectedAddonsPrice: addonsTotal,
                        );
                      }
                      Haptics.medium();
                      _cartBarKey.currentState?.bump();
                    }

                    if (anchorKey == null) {
                      addAll();
                      return;
                    }

                    AddToCartAnimation.run(
                      context: context,
                      startKey: startKey,
                      endKey: anchorKey,
                      imageUrl: widget.food.imageUrl,
                      onAnimationComplete: addAll,
                    );
                  },
                  borderRadius: BorderRadius.circular(28),
                  child: Ink(
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A00),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shopping_cart_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Add to Cart • ₹${(unitPrice * _quantity).toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}
