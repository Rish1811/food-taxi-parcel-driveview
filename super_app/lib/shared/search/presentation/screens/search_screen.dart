import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';
import 'package:superapp_user/shared/search/data/search_result.dart';
import 'package:superapp_user/modules/food/data/models/store99_product.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/modules/food/presentation/cart/utils/cart_restaurant_guard.dart';
import 'package:superapp_user/modules/food/presentation/cart/viewmodels/cart_viewmodel.dart';
import 'package:superapp_user/design_system/components/feedback/app_snackbar.dart';
import 'package:superapp_user/design_system/components/skeletons/skeleton_loading.dart';
import 'package:superapp_user/design_system/components/media/smart_image.dart';
import 'package:superapp_user/modules/food/presentation/home/viewmodels/veg_filter_provider.dart';
import 'package:superapp_user/app/routing/route_names.dart';
import 'package:superapp_user/modules/food/presentation/restaurant/widgets/food_detail_sheet.dart';
import 'package:superapp_user/shared/search/presentation/viewmodels/search_state.dart';
import 'package:superapp_user/shared/search/presentation/viewmodels/search_viewmodel.dart';
import 'package:superapp_user/shared/search/presentation/widgets/voice_search_dialog.dart';

enum ResultCategoryFilter { all, dishes, restaurants, store99 }

/// Premium Search Screen matching Swiggy, Blinkit & Zepto UI/UX design spec.
class SearchScreen extends ConsumerStatefulWidget {
  final SearchMode initialMode;
  final String? initialQuery;

  const SearchScreen({
    super.key,
    this.initialMode = SearchMode.home,
    this.initialQuery,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _textController;
  ResultCategoryFilter _categoryFilter = ResultCategoryFilter.all;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialMode == SearchMode.store99) {
      _categoryFilter = ResultCategoryFilter.store99;
    }

    Future.microtask(() {
      final vm = ref.read(searchViewModelProvider.notifier);
      vm.setMode(widget.initialMode);
      if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
        developer.log('[VOICE] Search query passed: "${widget.initialQuery}"', name: 'VOICE');
        developer.log('[VOICE] Search started for query: "${widget.initialQuery}"', name: 'VOICE');
        vm.submitQuery(widget.initialQuery!);
      }
    });
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery &&
        widget.initialQuery != null &&
        widget.initialQuery!.isNotEmpty) {
      _textController.text = widget.initialQuery!;
      developer.log('[VOICE] Search query passed: "${widget.initialQuery}"', name: 'VOICE');
      developer.log('[VOICE] Search started for query: "${widget.initialQuery}"', name: 'VOICE');
      ref.read(searchViewModelProvider.notifier).submitQuery(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onResultTap(SearchResult result) {
    Haptics.light();
    ref.read(searchViewModelProvider.notifier).submitQuery(result.title);

    if (result.type == SearchResultType.restaurant &&
        result.rawItem is RestaurantModel) {
      context.push(
        RouteNames.restaurantDetail,
        extra: result.rawItem as RestaurantModel,
      );
      return;
    }

    final FoodModel food;
    if (result.rawItem is FoodModel) {
      food = result.rawItem as FoodModel;
    } else if (result.rawItem is Store99Product) {
      food = (result.rawItem as Store99Product).toFoodModel();
    } else {
      food = FoodModel(
        id: result.id,
        restaurantId: 'r1',
        name: result.title,
        description: result.subtitle,
        price: result.price ?? 99,
        imageUrl: result.imageUrl,
        rating: result.rating ?? 4.5,
      );
    }

    FoodDetailSheet.show(context, food);
  }

  Future<void> _addDishToCart(SearchResult item) async {
    Haptics.success();
    final FoodModel food;
    if (item.rawItem is FoodModel) {
      food = item.rawItem as FoodModel;
    } else if (item.rawItem is Store99Product) {
      final p = item.rawItem as Store99Product;
      food = FoodModel(
        id: p.id,
        restaurantId: p.restaurantId,
        name: p.name,
        description: p.description,
        price: p.price,
        imageUrl: p.imageUrl,
        rating: p.rating,
        isPopular: true,
      );
    } else {
      food = FoodModel(
        id: item.id,
        restaurantId: 'r1',
        name: item.title,
        description: item.subtitle,
        price: item.price ?? 99,
        imageUrl: item.imageUrl,
        rating: item.rating ?? 4.5,
      );
    }

    final allowed = await ensureCartRestaurant(context, ref, food.restaurantId);
    if (!allowed || !mounted) return;

    ref.read(cartViewModelProvider.notifier).addItem(food);

    AppSnackbar.success(
      context,
      'Added "${item.title}" to cart!',
      duration: const Duration(seconds: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final searchState = ref.watch(searchViewModelProvider);
    final vm = ref.read(searchViewModelProvider.notifier);

    // Synchronize text field when voice search updates query
    if (searchState.query != _textController.text && !searchState.isSearching) {
      _textController.value = TextEditingController.fromValue(
        TextEditingValue(
          text: searchState.query,
          selection: TextSelection.collapsed(offset: searchState.query.length),
        ),
      ).value;
    }

    final isVegOnly = ref.watch(vegFilterProvider);

    final rawResults = searchState.results;
    var results = isVegOnly
        ? rawResults.where((r) {
            if (r.rawItem is FoodModel) return (r.rawItem as FoodModel).isVeg;
            if (r.rawItem is RestaurantModel) return (r.rawItem as RestaurantModel).isPureVeg;
            if (r.rawItem is Store99Product) return (r.rawItem as Store99Product).isVeg;
            return true;
          }).toList()
        : rawResults;

    if (_categoryFilter == ResultCategoryFilter.dishes) {
      results = results.where((r) => r.type != SearchResultType.restaurant).toList();
    } else if (_categoryFilter == ResultCategoryFilter.restaurants) {
      results = results.where((r) => r.type == SearchResultType.restaurant).toList();
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Modern Search Bar Header
            _buildSearchHeader(context, isDark, searchState, vm),

            // 2. Modern Filter Chips
            _buildModeTabs(context, isDark, searchState, vm),

            // 3. Main Results Area
            Expanded(
              child: searchState.isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: SkeletonRestaurantList(count: 3),
                    )
                  : searchState.query.trim().isEmpty
                  ? _buildDefaultState(context, isDark, searchState, vm)
                  : results.isEmpty
                  ? _buildEmptyState(context, isDark, searchState.query)
                  : _buildResultsSection(
                      context,
                      isDark,
                      searchState.query,
                      results,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SEARCH HEADER ====================

  Widget _buildSearchHeader(
    BuildContext context,
    bool isDark,
    SearchState state,
    SearchViewModel vm,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 16.w, 4.h),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(RouteNames.home);
              }
            },
            icon: Icon(
              Icons.arrow_back,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Container(
              height: 54.h,
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
                      controller: _textController,
                      autofocus: true,
                      textAlignVertical: TextAlignVertical.center,
                      onChanged: vm.onQueryChanged,
                      onSubmitted: vm.submitQuery,
                      style: TextStyle(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      decoration: InputDecoration(
                        hintText: state.mode == SearchMode.home
                            ? 'Search "Burger", "Pizza", "K9"...'
                            : 'Search 99 Store deals, dishes...',
                        hintStyle: TextStyle(
                          fontSize: 14.sp,
                          color: (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight)
                              .withValues(alpha: 0.65),
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
                  if (state.query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _textController.clear();
                        vm.clearQuery();
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

                  // Mic Icon Button in Soft Orange Circle
                  GestureDetector(
                    onTap: () async {
                      Haptics.light();
                      final query = await VoiceSearchDialog.show(context);
                      if (query != null && query.trim().isNotEmpty && context.mounted) {
                        developer.log('[VOICE] Search query passed: "$query"', name: 'VOICE');
                        developer.log('[VOICE] Search started for query: "$query"', name: 'VOICE');
                        _textController.text = query.trim();
                        ref.read(searchViewModelProvider.notifier).submitQuery(query.trim());
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
          ),
        ],
      ),
    );
  }

  // ==================== MODE TABS ====================

  Widget _buildModeTabs(
    BuildContext context,
    bool isDark,
    SearchState state,
    SearchViewModel vm,
  ) {
    final chips = [
      (
        label: 'All',
        icon: '🍽',
        filter: ResultCategoryFilter.all,
        mode: SearchMode.home,
      ),
      (
        label: 'Dishes',
        icon: '🍕',
        filter: ResultCategoryFilter.dishes,
        mode: SearchMode.home,
      ),
      (
        label: 'Restaurants',
        icon: '🏪',
        filter: ResultCategoryFilter.restaurants,
        mode: SearchMode.home,
      ),
      (
        label: '₹99 Store',
        icon: '🏷',
        filter: ResultCategoryFilter.store99,
        mode: SearchMode.store99,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 4.h),
      child: Row(
        children: chips.map((c) {
          final isSelected = state.mode == c.mode && _categoryFilter == c.filter;
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: _buildTabChip(
              label: c.label,
              emoji: c.icon,
              isSelected: isSelected,
              isDark: isDark,
              onTap: () {
                setState(() {
                  _categoryFilter = c.filter;
                });
                if (state.mode != c.mode) {
                  vm.setMode(c.mode);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabChip({
    required String label,
    required String emoji,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        Haptics.light();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: TextStyle(fontSize: 13.sp),
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textPrimaryLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== DEFAULT STATE ====================

  Widget _buildDefaultState(
    BuildContext context,
    bool isDark,
    SearchState state,
    SearchViewModel vm,
  ) {
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Haptics.light();
                    vm.clearRecentSearches();
                  },
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: state.recentSearches.map((item) {
                return Chip(
                  label: Text(item),
                  labelStyle: TextStyle(fontSize: 12.sp, color: textColor),
                  backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    side: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  deleteIcon: Icon(
                    Icons.close,
                    size: 14.sp,
                    color: secondaryTextColor,
                  ),
                  onDeleted: () {
                    Haptics.light();
                    vm.removeRecentSearch(item);
                  },
                );
              }).toList(),
            ),
            SizedBox(height: 20.h),
          ],

          Text(
            'Popular Keywords',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children:
                [
                  'Burger',
                  'Pizza',
                  'Chicken',
                  'Biryani',
                  'Thali',
                  'Paratha',
                  'Sandwich',
                  'Fries',
                ].map((kw) {
                  return ActionChip(
                    label: Text(kw),
                    labelStyle: TextStyle(
                      fontSize: 12.5.sp,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                      side: BorderSide(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                    ),
                    onPressed: () {
                      Haptics.light();
                      _textController.text = kw;
                      vm.submitQuery(kw);
                    },
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  // ==================== EMPTY STATE ====================

  Widget _buildEmptyState(BuildContext context, bool isDark, String query) {
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72.r,
              height: 72.r,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 36.sp,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'We couldn\'t find any matches for "$query". Try searching for another food item or restaurant.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5.sp,
                color: secondaryTextColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== RESULTS SECTION ====================

  Widget _buildResultsSection(
    BuildContext context,
    bool isDark,
    String query,
    List<SearchResult> results,
  ) {
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results Header (Title + Highlighted Query)
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Results',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 2.h),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    color: secondaryTextColor,
                    fontWeight: FontWeight.w400,
                  ),
                  children: [
                    TextSpan(
                      text:
                          'Showing ${results.length} ${results.length == 1 ? 'result' : 'results'} for ',
                    ),
                    TextSpan(
                      text: '"$query"',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Results List
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            itemCount: results.length,
            separatorBuilder: (context, index) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              final item = results[index];
              return _buildResultCard(context, isDark, item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    bool isDark,
    SearchResult item,
  ) {
    final isRestaurant = item.type == SearchResultType.restaurant;
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: () => _onResultTap(item),
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
          border: Border.all(
            color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Image Box
            ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: SizedBox(
                width: isRestaurant ? 76.r : 80.r,
                height: isRestaurant ? 76.r : 80.r,
                child: SmartImage(
                  url: item.imageUrl,
                  category: isRestaurant
                      ? ImageCategory.restaurant
                      : ImageCategory.food,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(width: 12.w),

            // Info Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge Row (Type Label + Green Star Rating)
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFECE0),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          isRestaurant ? 'Restaurant' : 'Dish',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFF6D00),
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Icon(
                        Icons.star_rounded,
                        color: const Color(0xFF16A34A),
                        size: 14.sp,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        '${item.rating ?? 4.0}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 4.h),

                  // Title & Price Row (if dish)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5.sp,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (!isRestaurant && item.price != null) ...[
                        SizedBox(width: 6.w),
                        Text(
                          '₹${item.price!.toInt()}',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),

                  SizedBox(height: 2.h),

                  // Subtitle
                  Text(
                    item.subtitle,
                    maxLines: isRestaurant ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: secondaryTextColor,
                      height: 1.3,
                    ),
                  ),

                  SizedBox(height: 4.h),

                  // Bottom Detail Row
                  if (isRestaurant && item.rawItem is RestaurantModel) ...[
                    Builder(
                      builder: (context) {
                        final r = item.rawItem as RestaurantModel;
                        final hasTime = r.deliveryTime.isNotEmpty;
                        final hasFee = r.isFreeDelivery || r.deliveryFee >= 0;
                        if (!hasTime && !hasFee) return const SizedBox.shrink();

                        return Row(
                          children: [
                            if (hasTime) ...[
                              Icon(
                                Icons.access_time_rounded,
                                size: 12.sp,
                                color: secondaryTextColor,
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                r.deliveryTime,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                            if (hasTime && hasFee) ...[
                              SizedBox(width: 6.w),
                              Text(
                                '•',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 10.sp,
                                ),
                              ),
                              SizedBox(width: 6.w),
                            ],
                            if (hasFee) ...[
                              Icon(
                                Icons.two_wheeler_rounded,
                                size: 12.sp,
                                color: secondaryTextColor,
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                r.isFreeDelivery || r.deliveryFee == 0
                                    ? 'Free Delivery'
                                    : '₹${r.deliveryFee.toStringAsFixed(0)} Delivery',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ] else if (!isRestaurant) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Veg Tag Icon
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5.w,
                            vertical: 1.5.h,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF16A34A),
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5.sp,
                                height: 5.sp,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF16A34A),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                'Veg',
                                style: TextStyle(
                                  color: const Color(0xFF16A34A),
                                  fontSize: 9.5.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Interactive + Add Button
                        InkWell(
                          onTap: () => _addDishToCart(item),
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  color: AppColors.primary,
                                  size: 15.sp,
                                ),
                                SizedBox(width: 2.w),
                                Text(
                                  'Add',
                                  style: TextStyle(
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (isRestaurant) ...[
              SizedBox(width: 4.w),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1),
                size: 22.sp,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
