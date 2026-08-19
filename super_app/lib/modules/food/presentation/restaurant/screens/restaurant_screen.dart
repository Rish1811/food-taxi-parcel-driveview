import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/modules/food/data/services/deep_link_service.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_menu_category.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/modules/food/presentation/cart/utils/cart_restaurant_guard.dart';
import 'package:superapp_user/modules/food/presentation/cart/viewmodels/cart_viewmodel.dart';
import 'package:superapp_user/modules/food/presentation/cart/widgets/floating_view_cart_bar.dart';
import 'package:superapp_user/design_system/components/skeletons/skeleton_loading.dart';
import 'package:superapp_user/design_system/components/media/smart_image.dart';
import 'package:superapp_user/modules/food/presentation/favorites/viewmodels/favorites_viewmodel.dart';
import 'package:superapp_user/app/routing/route_names.dart';
import 'package:superapp_user/shared/search/presentation/widgets/voice_search_dialog.dart';
import 'package:superapp_user/modules/food/presentation/restaurant/viewmodels/restaurant_state.dart';
import 'package:superapp_user/modules/food/presentation/restaurant/viewmodels/restaurant_viewmodel.dart';
import 'package:superapp_user/modules/food/presentation/restaurant/widgets/food_detail_sheet.dart';

class RestaurantScreen extends ConsumerStatefulWidget {
  final RestaurantModel? restaurant;

  const RestaurantScreen({super.key, this.restaurant});

  @override
  ConsumerState<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends ConsumerState<RestaurantScreen> {
  static const Color _priceGreen = Color(0xFF1FA855);

  late final TextEditingController _searchController;
  final GlobalKey<FloatingViewCartBarState> _cartBarKey =
      GlobalKey<FloatingViewCartBarState>();
  final Map<String, GlobalKey> _dishImageKeys = {};

  // ---- Category jump-navigation (chip bar <-> menu sections) ----
  final ScrollController _scrollController = ScrollController();
  final ScrollController _chipScrollController = ScrollController();
  final GlobalKey _topAnchorKey = GlobalKey();
  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, GlobalKey> _chipKeys = {};
  String _activeCategoryId = 'all';
  bool _isAutoScrolling = false;
  List<String> _lastSectionOrder = [];

  double get _categoryBarHeight => 56.h;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController.addListener(_onMainScroll);

    Future.microtask(() {
      Haptics.light();
      final targetRestaurant = widget.restaurant;
      if (targetRestaurant == null) return;
      ref.read(restaurantViewModelProvider.notifier).loadMenu(targetRestaurant);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _chipScrollController.dispose();
    super.dispose();
  }

  // ==================== CATEGORY JUMP NAVIGATION ====================

  void _onCategoryChipTap(String categoryId) {
    Haptics.light();
    setState(() => _activeCategoryId = categoryId);

    final targetKey = categoryId == 'all'
        ? _topAnchorKey
        : _sectionKeys[categoryId];
    final targetContext = targetKey?.currentContext;
    if (targetContext != null) {
      _isAutoScrolling = true;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0,
      ).then((_) {
        if (mounted) _isAutoScrolling = false;
      });
    }
    _ensureChipVisible(categoryId);
  }

  void _ensureChipVisible(String categoryId) {
    final chipContext = _chipKeys[categoryId]?.currentContext;
    if (chipContext == null) return;

    // Scope to the horizontal chip Scrollable only. The unscoped
    // Scrollable.ensureVisible() walks every ancestor Scrollable, which
    // would also drag the outer vertical CustomScrollView back toward
    // this pinned header's unpinned position.
    final horizontalScrollable = Scrollable.maybeOf(
      chipContext,
      axis: Axis.horizontal,
    );
    final renderObject = chipContext.findRenderObject();
    if (horizontalScrollable == null || renderObject == null) return;

    horizontalScrollable.position.ensureVisible(
      renderObject,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: 0.5,
    );
  }

  void _onMainScroll() {
    if (_isAutoScrolling || !mounted || _lastSectionOrder.isEmpty) return;

    final topThreshold =
        MediaQuery.of(context).padding.top + 58.h + _categoryBarHeight + 4.h;
    String newActive = 'all';
    for (final id in _lastSectionOrder) {
      final ctx = _sectionKeys[id]?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= topThreshold) {
        newActive = id;
      } else {
        break;
      }
    }

    if (newActive != _activeCategoryId) {
      setState(() => _activeCategoryId = newActive);
      _ensureChipVisible(newActive);
    }
  }

  int _getQuantity(CartState cartState, String foodId) {
    for (final item in cartState.items) {
      if (item.food.id == foodId) return item.quantity;
    }
    return 0;
  }

  String? _getCartItemId(CartState cartState, String foodId) {
    for (final item in cartState.items) {
      if (item.food.id == foodId) return item.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final restaurantState = ref.watch(restaurantViewModelProvider);
    final cartState = ref.watch(cartViewModelProvider);
    final currentRestaurant = restaurantState.restaurant ?? widget.restaurant;

    // Reached only via a restaurant card, so this is defensive rather than a
    // real state — but it must not fabricate a placeholder restaurant.
    if (currentRestaurant == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Restaurant unavailable')),
      );
    }

    final isFavorite = ref.watch(
      favoritesViewModelProvider.select(
        (s) => s.value?.restaurantIds.contains(currentRestaurant.id) ?? false,
      ),
    );

    final groupedByCategory = restaurantState.isLoading
        ? const <String, List<FoodModel>>{}
        : ref
              .read(restaurantViewModelProvider.notifier)
              .groupFilteredByCategory();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              Column(
                children: [
                  // FIXED RESTAURANT HEADER (outside RefreshIndicator & ScrollView)
                  _buildTopSection(
                    context,
                    currentRestaurant,
                    isFavorite,
                  ),

                  // REFRESHABLE MENU CONTENT AREA
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        Haptics.light();
                        await ref
                            .read(restaurantViewModelProvider.notifier)
                            .loadMenu(currentRestaurant, isRefresh: true);
                      },
                      color: AppColors.primary,
                      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          // Sticky Premium Search Bar
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _StickySearchBarDelegate(
                              child: _buildSearchBar(
                                context,
                                currentRestaurant,
                                restaurantState,
                              ),
                              topPadding: 0,
                            ),
                          ),

                          // Sticky Category Chip Bar
                          if (restaurantState.categories.length > 1)
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _StickyCategoryBarDelegate(
                                child: _buildCategoryChipsBar(context, restaurantState),
                                barHeight: _categoryBarHeight,
                              ),
                            ),

                          // Main Content Body
                          SliverToBoxAdapter(
                            child: restaurantState.isLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Column(
                                      children: [
                                        SkeletonFoodItemCard(),
                                        SkeletonFoodItemCard(),
                                        SkeletonFoodItemCard(),
                                      ],
                                    ),
                                  )
                                : Column(
                                    children: [
                                      SizedBox(height: 12.h),
                                      // Segmented Filter (All | Veg | Non-Veg)
                                      _buildSegmentedFilter(context, restaurantState),
                                      SizedBox(height: 20.h),
                                      // Dishes grouped into jump-to category sections
                                      _buildCategorySections(
                                        context,
                                        restaurantState.categories,
                                        groupedByCategory,
                                        cartState,
                                      ),
                                      SizedBox(height: 110.h),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Floating View Cart Bar
              FloatingViewCartBar(
                key: _cartBarKey,
                onTap: () {
                  Haptics.light();
                  context.go(RouteNames.cart);
                },
              ),

              // Floating MENU Button
              Positioned(
                right: 20.w,
                bottom: cartState.items.isNotEmpty ? 90.h : 20.h,
                child: _buildFloatingMenuButton(context, restaurantState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== TOP HEADER SECTION ====================

  Widget _buildTopSection(
    BuildContext context,
    RestaurantModel restaurant,
    bool isFavorite,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36.r),
          bottomRight: Radius.circular(36.r),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8.h,
        left: 16.w,
        right: 16.w,
        bottom: 8.h,
      ),
      child: Column(
        children: [
          // App Bar Area
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  Haptics.light();
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(RouteNames.home);
                  }
                },
                child: Icon(Icons.arrow_back, color: Colors.white, size: 24.sp),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Haptics.light();
                      final text = DeepLinkService.generateRestaurantShareText(
                        restaurantName: restaurant.name,
                        restaurantId: restaurant.id,
                        cuisines: restaurant.tags.join(', '),
                      );
                      SharePlus.instance.share(ShareParams(text: text));
                    },
                    child: Icon(
                      Icons.share_outlined,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 18.w),
                  GestureDetector(
                    onTap: () {
                      Haptics.medium();
                      ref
                          .read(favoritesViewModelProvider.notifier)
                          .toggle(restaurant.id, restaurant);
                    },
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite
                          ? const Color(0xFFFF4B72)
                          : Colors.white,
                      size: 24.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Overlapping Card
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (restaurant.isFeatured) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: AppColors.primary,
                        size: 14.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'Featured',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            restaurant.name,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E1E1E),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            restaurant.deliveryTime.isNotEmpty
                                ? '${restaurant.deliveryTime}  |  ${restaurant.distanceKm.toStringAsFixed(1)} km ▾'
                                : '${restaurant.distanceKm.toStringAsFixed(1)} km ▾',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (restaurant.rating > 0)
                      Column(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1FA855),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  restaurant.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 2.w),
                                Icon(
                                  Icons.star,
                                  color: Colors.white,
                                  size: 12.sp,
                                ),
                              ],
                            ),
                          ),
                          if (restaurant.reviewCount > 0) ...[
                            SizedBox(height: 4.h),
                            Text(
                              '${restaurant.reviewCount} ratings',
                              style: TextStyle(
                                fontSize: 9.sp,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
                SizedBox(height: 16.h),

                if (!restaurant.isOpen) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A1C1A) : const Color(0xFFFFF8F6),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isDark ? const Color(0xFF4A2B24) : const Color(0xFFFFE4E0),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 2.h),
                          child: Icon(
                            Icons.access_time_rounded,
                            size: 16.sp,
                            color: const Color(0xFFC2410C),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'This restaurant is currently closed.',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFFFDBA74)
                                      : const Color(0xFF7C2D12),
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'It will accept orders once it reopens.',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? const Color(0xFFFED7AA)
                                      : const Color(0xFF9A3412).withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],

                if (restaurant.offerBadges.isNotEmpty) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          (constraints.constrainWidth() / 8).floor(),
                          (index) => Container(
                            width: 4,
                            height: 1,
                            color: isDark
                                ? AppColors.borderDark
                                : Colors.grey.shade300,
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      _buildStarburstOfferIcon(),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          restaurant.offerBadges.first,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E1E1E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== PREMIUM STICKY SEARCH BAR ====================

  Widget _buildSearchBar(
    BuildContext context,
    RestaurantModel restaurant,
    RestaurantState state,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vm = ref.read(restaurantViewModelProvider.notifier);

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 2.h, 16.w, 4.h),
      color: isDark ? AppColors.backgroundDark : Colors.white,
      child: Container(
        height: 52.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(28.r),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.2,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              size: 22.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: TextField(
                controller: _searchController,
                textAlignVertical: TextAlignVertical.center,
                onChanged: (val) {
                  vm.setSearchQuery(val);
                },
                onTap: () {
                  Haptics.light();
                },
                style: TextStyle(
                  fontSize: 14.5.sp,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Search for dishes in ${restaurant.name}',
                  hintStyle: TextStyle(
                    fontSize: 13.5.sp,
                    color: (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight)
                        .withValues(alpha: 0.65),
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (state.searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  Haptics.light();
                  _searchController.clear();
                  vm.setSearchQuery('');
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Icon(
                    Icons.close_rounded,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    size: 20.sp,
                  ),
                ),
              ),
            SizedBox(width: 6.w),
            GestureDetector(
              onTap: () async {
                Haptics.light();
                final query = await VoiceSearchDialog.show(context);
                if (query != null && query.trim().isNotEmpty && context.mounted) {
                  developer.log('[VOICE] Search query passed: "$query"', name: 'VOICE');
                  developer.log('[VOICE] Search started for query: "$query"', name: 'VOICE');
                  _searchController.text = query.trim();
                  vm.setSearchQuery(query.trim());
                }
              },
              child: Container(
                padding: EdgeInsets.all(7.r),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3E0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic_rounded,
                  color: const Color(0xFFFF6D00),
                  size: 20.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SINGLE SEGMENTED FILTER ====================

  Widget _buildSegmentedFilter(BuildContext context, RestaurantState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vm = ref.read(restaurantViewModelProvider.notifier);

    int selectedIndex = 0;
    if (state.isVegOnly) {
      selectedIndex = 1;
    } else if (state.isNonVegOnly) {
      selectedIndex = 2;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        height: 40.h,
        padding: EdgeInsets.all(4.r),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isDark ? AppColors.borderDark : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildSegmentSegment(
                context: context,
                label: 'All',
                isSelected: selectedIndex == 0,
                icon: null,
                onTap: () {
                  Haptics.light();
                  if (state.isVegOnly) vm.toggleVegOnly();
                  if (state.isNonVegOnly) vm.toggleNonVegOnly();
                },
              ),
            ),
            Expanded(
              child: _buildSegmentSegment(
                context: context,
                label: 'Veg',
                isSelected: selectedIndex == 1,
                icon: _buildVegIcon(size: 10),
                onTap: () {
                  Haptics.light();
                  if (state.isNonVegOnly) vm.toggleNonVegOnly();
                  vm.toggleVegOnly();
                },
              ),
            ),
            Expanded(
              child: _buildSegmentSegment(
                context: context,
                label: 'Non-Veg',
                isSelected: selectedIndex == 2,
                icon: _buildNonVegIcon(size: 10),
                onTap: () {
                  Haptics.light();
                  if (state.isVegOnly) vm.toggleVegOnly();
                  vm.toggleNonVegOnly();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentSegment({
    required BuildContext context,
    required String label,
    required bool isSelected,
    Widget? icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.cardDark : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[icon, SizedBox(width: 4.w)],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? _priceGreen
                    : (isDark ? AppColors.textSecondaryDark : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== CATEGORY CHIP BAR (jump navigation) ====================

  Widget _buildCategoryChipsBar(BuildContext context, RestaurantState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final seenIds = <String>{};
    final seenNames = <String>{};
    final categories = <RestaurantMenuCategory>[];

    for (final cat in state.categories) {
      final idKey = cat.id.trim();
      final nameKey = cat.name.trim().toLowerCase();

      if (idKey.isNotEmpty && seenIds.contains(idKey)) continue;
      if (nameKey.isNotEmpty && seenNames.contains(nameKey)) continue;

      if (idKey.isNotEmpty) seenIds.add(idKey);
      if (nameKey.isNotEmpty) seenNames.add(nameKey);
      categories.add(cat);
    }

    if (categories.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 40.h,
      child: ListView.separated(
        controller: _chipScrollController,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: categories.length,
        separatorBuilder: (_, _) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isActive = _activeCategoryId == category.id;
          final chipKey = _chipKeys.putIfAbsent(category.id, () => GlobalKey());

          return GestureDetector(
            key: chipKey,
            onTap: () => _onCategoryChipTap(category.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary
                    : (isDark ? AppColors.surfaceDark : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isActive
                      ? AppColors.primary
                      : (isDark ? AppColors.borderDark : Colors.grey.shade300),
                  width: 1,
                ),
              ),
              child: Text(
                category.name,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive
                      ? Colors.white
                      : (isDark
                            ? AppColors.textSecondaryDark
                            : Colors.grey[700]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }



  // ==================== CATEGORY SECTIONS (jump-to-section menu) ====================

  Widget _buildCategorySections(
    BuildContext context,
    List<RestaurantMenuCategory> categories,
    Map<String, List<FoodModel>> grouped,
    CartState cartState,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sections = categories
        .where((c) => c.id != 'all' && (grouped[c.id]?.isNotEmpty ?? false))
        .toList();

    _lastSectionOrder = sections.map((c) => c.id).toList();

    if (sections.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.h),
          child: Text(
            'No dishes match your filters.',
            style: TextStyle(
              fontSize: 14.sp,
              color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return Column(
      key: _topAnchorKey,
      children: [
        for (final category in sections) ...[
          Padding(
            key: _sectionKeys.putIfAbsent(category.id, () => GlobalKey()),
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
                Text(
                  '${grouped[category.id]!.length} items',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _buildDishesGrid(context, grouped[category.id]!, cartState),
          SizedBox(height: 24.h),
        ],
      ],
    );
  }

  // ==================== DISHES GRID WITH FOOD CARD NAVIGATION ====================

  Widget _buildDishesGrid(
    BuildContext context,
    List<FoodModel> dishes,
    CartState cartState,
  ) {
    if (dishes.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.h),
          child: Text(
            'No dishes match your filters.',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: dishes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16.w,
          mainAxisSpacing: 24.h,
          childAspectRatio: 0.58,
        ),
        itemBuilder: (context, index) {
          return _buildGridDishCard(context, dishes[index], cartState);
        },
      ),
    );
  }

  Widget _buildGridDishCard(
    BuildContext context,
    FoodModel dish,
    CartState cartState,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final quantity = _getQuantity(cartState, dish.id);
    final cartItemId = _getCartItemId(cartState, dish.id);

    return GestureDetector(
      onTap: () {
        Haptics.light();
        final restaurantName =
            (ref.read(restaurantViewModelProvider).restaurant ??
                    widget.restaurant)
                ?.name;
        FoodDetailSheet.show(context, dish, restaurantName: restaurantName);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                key: _dishImageKeys.putIfAbsent(dish.id, () => GlobalKey()),
                height: 140.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  color: isDark
                      ? AppColors.surfaceDark
                      : const Color(0xFFF0F0F0),
                ),
                clipBehavior: Clip.antiAlias,
                child: SmartImage(
                  url: dish.imageUrl,
                  category: ImageCategory.food,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              dish.isVeg ? _buildVegIcon(size: 10) : _buildNonVegIcon(size: 10),
              const Spacer(),
              if (dish.rating > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: _priceGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: _priceGreen, size: 9.sp),
                      SizedBox(width: 2.w),
                      Text(
                        dish.reviewCount > 0
                            ? '${dish.rating} (${dish.reviewCount})'
                            : '${dish.rating}',
                        style: TextStyle(
                          fontSize: 9.sp,
                          color: _priceGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          SizedBox(
            height: 32.h,
            child: Text(
              dish.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                height: 1.2,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${dish.price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                ),
              ),
              _buildAddButton(context, dish, quantity, cartItemId),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleFirstAddToCart(FoodModel dish) async {
    Haptics.light();
    await addFoodToCart(context, ref, dish);
  }

  Widget _buildAddButton(
    BuildContext context,
    FoodModel dish,
    int quantity,
    String? cartItemId,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasQty = quantity > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: hasQty ? 6.w : 16.w,
        vertical: hasQty ? 4.h : 6.h,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        border: Border.all(
          color: _priceGreen.withValues(alpha: hasQty ? 0.4 : 0.3),
        ),
        borderRadius: BorderRadius.circular(8.r),
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
              ? GestureDetector(
                  key: const ValueKey('add'),
                  onTap: () => _handleFirstAddToCart(dish),
                  child: Text(
                    'ADD',
                    style: TextStyle(
                      color: _priceGreen,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : Row(
                  key: const ValueKey('stepper'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: cartItemId == null
                          ? null
                          : () {
                              Haptics.light();
                              ref
                                  .read(cartViewModelProvider.notifier)
                                  .updateQuantity(cartItemId, quantity - 1);
                            },
                      child: Icon(
                        Icons.remove,
                        color: _priceGreen,
                        size: 14.sp,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      '$quantity',
                      style: TextStyle(
                        color: _priceGreen,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    GestureDetector(
                      onTap: () {
                        Haptics.light();
                        addFoodToCart(context, ref, dish);
                      },
                      child: Icon(Icons.add, color: _priceGreen, size: 14.sp),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ==================== FLOATING MENU BUTTON & CATEGORY BOTTOM SHEET ====================

  Widget _buildFloatingMenuButton(BuildContext context, RestaurantState state) {
    return GestureDetector(
      onTap: () {
        Haptics.medium();
        _showCategoryBottomSheet(context, state);
      },
      child: Container(
        width: 60.r,
        height: 60.r,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/menuicon.png',
              width: 20.sp,
              height: 20.sp,
              color: Colors.white,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.restaurant_menu, color: Colors.white, size: 20.sp),
            ),
            SizedBox(height: 2.h),
            Text(
              'MENU',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryBottomSheet(BuildContext context, RestaurantState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = state.categories;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24.r),
              topRight: Radius.circular(24.r),
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white30 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Menu Categories',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  separatorBuilder: (context, index) => Divider(
                    color: isDark ? AppColors.borderDark : Colors.grey.shade200,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final category = categories[index];

                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(vertical: 4.h),
                      title: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E1E1E),
                        ),
                      ),
                      trailing: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          '${category.itemCount}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _onCategoryChipTap(category.id);
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: 10.h),
            ],
          ),
        );
      },
    );
  }

  // ==================== SHARED HELPERS ====================

  Widget _buildStarburstOfferIcon() {
    return SizedBox(
      width: 28.sp,
      height: 28.sp,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(28.sp, 28.sp),
            painter: _StarburstPainter(color: AppColors.primary),
          ),
          Text(
            '%',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVegIcon({double size = 10}) {
    return Container(
      width: size.sp,
      height: size.sp,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF008A45), width: 1),
        borderRadius: BorderRadius.circular(2.r),
      ),
      alignment: Alignment.center,
      child: Container(
        width: (size * 0.4).sp,
        height: (size * 0.4).sp,
        decoration: const BoxDecoration(
          color: Color(0xFF008A45),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildNonVegIcon({double size = 10}) {
    return Container(
      width: size.sp,
      height: size.sp,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE23744), width: 1),
        borderRadius: BorderRadius.circular(2.r),
      ),
      alignment: Alignment.center,
      child: CustomPaint(
        size: Size((size * 0.5).sp, (size * 0.5).sp),
        painter: _TrianglePainter(color: const Color(0xFFE23744)),
      ),
    );
  }
}

// Delegate for Sticky Persistent Search Bar (safely positioned below Status Bar)
class _StickySearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double topPadding;

  _StickySearchBarDelegate({required this.child, required this.topPadding});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.backgroundDark : Colors.white,
      padding: EdgeInsets.only(top: topPadding),
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  double get maxExtent => 58.h + topPadding;

  @override
  double get minExtent => 58.h + topPadding;

  @override
  bool shouldRebuild(covariant _StickySearchBarDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.topPadding != topPadding;
  }
}

// Delegate for the sticky category chip bar, pinned directly under the
// search bar so the active section stays visible while the menu scrolls.
class _StickyCategoryBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double barHeight;

  _StickyCategoryBarDelegate({required this.child, required this.barHeight});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.backgroundDark : Colors.white,
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  double get maxExtent => barHeight;

  @override
  double get minExtent => barHeight;

  @override
  bool shouldRebuild(covariant _StickyCategoryBarDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.barHeight != barHeight;
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StarburstPainter extends CustomPainter {
  final Color color;
  _StarburstPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.8;
    const points = 12;

    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = (i * math.pi) / points;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
