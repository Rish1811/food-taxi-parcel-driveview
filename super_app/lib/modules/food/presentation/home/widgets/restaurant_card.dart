import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/components/media/smart_image.dart';
import 'package:superapp_user/modules/food/presentation/favorites/viewmodels/favorites_viewmodel.dart';
import 'package:superapp_user/app/routing/route_names.dart';
import 'package:superapp_user/modules/food/presentation/restaurant/viewmodels/restaurant_detail_viewmodel.dart';

class RestaurantCard extends ConsumerStatefulWidget {
  final RestaurantModel restaurant;
  final int index;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.index = 0,
  });

  @override
  ConsumerState<RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends ConsumerState<RestaurantCard> {
  late final ValueNotifier<int> _activePageNotifier;

  @override
  void initState() {
    super.initState();
    _activePageNotifier = ValueNotifier<int>(0);
  }

  @override
  void dispose() {
    _activePageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuAsync = ref.watch(restaurantMenuProvider(restaurant.id));
    final menu = menuAsync.asData?.value ?? const <FoodModel>[];

    final featuredDish = menu.isEmpty
        ? null
        : menu.firstWhere((f) => f.isPopular, orElse: () => menu.first);

    final foodMenuUrls = menu
        .map((f) => f.imageUrl)
        .where((url) => url.isNotEmpty)
        .toList();
    final modelMenuUrls = restaurant.menuImages
        .where((url) => url.isNotEmpty)
        .toList();
    final modelCoverUrls = restaurant.coverImages
        .where((url) => url.isNotEmpty)
        .toList();

    final List<String> imageSlides;
    if (foodMenuUrls.isNotEmpty) {
      imageSlides = foodMenuUrls;
    } else if (modelMenuUrls.isNotEmpty) {
      imageSlides = modelMenuUrls;
    } else if (modelCoverUrls.isNotEmpty) {
      imageSlides = modelCoverUrls;
    } else if (restaurant.imageUrl.isNotEmpty) {
      imageSlides = [restaurant.imageUrl];
    } else {
      imageSlides = const [];
    }

    final startingPrice = restaurant.priceForOne > 0
        ? restaurant.priceForOne
        : (featuredDish != null ? featuredDish.price : 0.0);

    final List<double> slidePrices;
    final List<String> slideDishLabels;
    if (foodMenuUrls.isNotEmpty) {
      final menuWithImages = menu.where((f) => f.imageUrl.isNotEmpty).toList();
      slidePrices = menuWithImages.map((f) => f.price).toList();
      slideDishLabels = menuWithImages.map((f) {
        return '${f.name}${f.price > 0 ? ' • ₹${f.price.toStringAsFixed(0)}' : ''}';
      }).toList();
    } else if (menu.isNotEmpty) {
      slidePrices = menu.map((f) => f.price).toList();
      slideDishLabels = menu.map((f) {
        return '${f.name}${f.price > 0 ? ' • ₹${f.price.toStringAsFixed(0)}' : ''}';
      }).toList();
    } else {
      slidePrices = const [];
      slideDishLabels = const [];
    }

    final top3MenuItems = menu.take(3).map((f) {
      return '${f.name}${f.price > 0 ? ' • ₹${f.price.toStringAsFixed(0)}' : ''}';
    }).toList();

    final List<String> displayTopItems;
    if (top3MenuItems.isNotEmpty) {
      displayTopItems = top3MenuItems;
    } else if (restaurant.featuredDishName != null) {
      displayTopItems = [
        '${restaurant.featuredDishName}${startingPrice > 0 ? ' • ₹${startingPrice.toStringAsFixed(0)}' : ''}',
        if (restaurant.tags.isNotEmpty) restaurant.tags.first,
      ];
    } else if (restaurant.tags.isNotEmpty) {
      displayTopItems = restaurant.tags.take(3).toList();
    } else {
      displayTopItems = const [];
    }

    return _EntranceAnimationWrapper(
      index: widget.index,
      child: GestureDetector(
        onTap: () {
          Haptics.light();
          context.push(RouteNames.restaurantDetail, extra: restaurant);
        },
        child: Container(
          margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: AppColors.shadow1,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MediaCarousel(
                restaurant: restaurant,
                restaurantId: restaurant.id,
                imageSlides: imageSlides,
                isOpen: restaurant.isOpen,
                featuredPriceBadge: startingPrice > 0 ? '₹${startingPrice.toStringAsFixed(0)} for one' : null,
                featuredDishName: restaurant.featuredDishName ?? featuredDish?.name,
                topMenuItemNames: slideDishLabels.isNotEmpty ? slideDishLabels : displayTopItems,
                onPageChanged: (page) {
                  _activePageNotifier.value = page;
                },
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 8.h),
                child: _RestaurantInfo(
                  restaurant: restaurant,
                  isDark: isDark,
                  startingPrice: startingPrice,
                  slidePrices: slidePrices,
                  activePageNotifier: _activePageNotifier,
                  topMenuItemNames: displayTopItems,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntranceAnimationWrapper extends StatefulWidget {
  final int index;
  final Widget child;

  const _EntranceAnimationWrapper({
    required this.index,
    required this.child,
  });

  @override
  State<_EntranceAnimationWrapper> createState() => _EntranceAnimationWrapperState();
}

class _EntranceAnimationWrapperState extends State<_EntranceAnimationWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);
    _scaleAnimation = Tween<double>(begin: 0.97, end: 1.0).animate(curvedAnimation);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(curvedAnimation);

    final delayMs = (widget.index % 6) * 60;
    if (delayMs > 0) {
      _delayTimer = Timer(Duration(milliseconds: delayMs), () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}



class _RestaurantInfo extends ConsumerWidget {
  final RestaurantModel restaurant;
  final bool isDark;
  final double startingPrice;
  final List<double> slidePrices;
  final ValueNotifier<int>? activePageNotifier;
  final List<String> topMenuItemNames;

  const _RestaurantInfo({
    required this.restaurant,
    required this.isDark,
    required this.startingPrice,
    this.slidePrices = const [],
    this.activePageNotifier,
    this.topMenuItemNames = const [],
  });

  Widget _buildInlineItem({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 12.sp, color: color),
        SizedBox(width: 3.w),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final locationLabel = restaurant.area;

    // Info Line Spans: Clock 30 mins • ₹134 for one
    final infoSpans = <InlineSpan>[];

    if (restaurant.deliveryTime.isNotEmpty) {
      infoSpans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(
          Icons.access_time_rounded,
          size: 13.sp,
          color: const Color(0xFFE65100),
        ),
      ));
      infoSpans.add(TextSpan(
        text: ' ${restaurant.deliveryTime}',
        style: TextStyle(
          color: secondaryColor,
          fontWeight: FontWeight.w500,
          fontSize: 12.sp,
        ),
      ));
    }

    if (restaurant.distanceKm > 0) {
      if (infoSpans.isNotEmpty) {
        infoSpans.add(TextSpan(
          text: '   •   ',
          style: TextStyle(color: secondaryColor.withValues(alpha: 0.5)),
        ));
      }
      infoSpans.add(TextSpan(
        text: '${restaurant.distanceKm.toStringAsFixed(1)} km',
        style: TextStyle(
          color: secondaryColor,
          fontWeight: FontWeight.w500,
          fontSize: 12.sp,
        ),
      ));
    }

    final priceWidget = (slidePrices.isNotEmpty || startingPrice > 0)
        ? ValueListenableBuilder<int>(
            valueListenable: activePageNotifier ?? ValueNotifier<int>(0),
            builder: (context, currentPage, _) {
              final activePrice = (slidePrices.isNotEmpty &&
                      currentPage < slidePrices.length &&
                      slidePrices[currentPage] > 0)
                  ? slidePrices[currentPage]
                  : (slidePrices.isNotEmpty &&
                          (currentPage % slidePrices.length) < slidePrices.length &&
                          slidePrices[currentPage % slidePrices.length] > 0
                      ? slidePrices[currentPage % slidePrices.length]
                      : startingPrice);
              if (activePrice <= 0) return const SizedBox.shrink();
              return Text(
                '₹${activePrice.toStringAsFixed(0)} for one',
                style: TextStyle(
                  color: secondaryColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 12.sp,
                ),
              );
            },
          )
        : null;

    if (priceWidget != null) {
      if (infoSpans.isNotEmpty) {
        infoSpans.add(TextSpan(
          text: '   •   ',
          style: TextStyle(color: secondaryColor.withValues(alpha: 0.5)),
        ));
      }
      infoSpans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: priceWidget,
      ));
    }

    final cuisinesText = restaurant.tags.isNotEmpty
        ? restaurant.tags.join('  •  ')
        : (restaurant.restaurantTags.isNotEmpty
            ? restaurant.restaurantTags.join('  •  ')
            : 'Desserts  •  North Indian  •  Snacks');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Restaurant Name Header Row with Green Rating Pill (Top-Right)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                restaurant.name,
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (restaurant.rating > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: 13.sp,
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      restaurant.rating.toStringAsFixed(1),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        SizedBox(height: 3.h),

        // 2. Delivery Time / Cost Line & Right-Side Inline Location / Status
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(children: infoSpans),
              ),
            ),
            if (locationLabel.isNotEmpty)
              _buildInlineItem(
                icon: Icons.location_on_rounded,
                label: locationLabel,
                color: const Color(0xFFE65100),
              )
            else if (!restaurant.isOpen)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF3F1D24)
                      : const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF881337)
                        : const Color(0xFFFECDD3),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12.sp,
                      color: const Color(0xFFE11D48),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'Closed Now',
                      style: TextStyle(
                        color: const Color(0xFFE11D48),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        SizedBox(height: 3.h),

        // 3. Cuisines Line & Right-Aligned Inline Pure Veg Badge directly below Location
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                cuisinesText,
                style: TextStyle(
                  fontSize: 11.5.sp,
                  color: secondaryColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (restaurant.isPureVeg) ...[
              SizedBox(width: 8.w),
              _buildInlineItem(
                icon: Icons.eco_rounded,
                label: 'Pure Veg',
                color: const Color(0xFF2E7D32),
              ),
            ],
          ],
        ),

        // 4. Temporary Closed Banner (Matching Screenshot)
        if (!restaurant.isOpen) ...[
          SizedBox(height: 6.h),
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
                    size: 15.sp,
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
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFFDBA74)
                              : const Color(0xFF7C2D12),
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        'It will accept orders once it reopens.',
                        style: TextStyle(
                          fontSize: 10.5.sp,
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
        ],

        // 5. Must Try / Popular Dish Banner Row
        if (topMenuItemNames.isNotEmpty || restaurant.featuredDishName != null) ...[
          SizedBox(height: 5.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF261D1A)
                  : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF452B20)
                    : const Color(0xFFFED7AA),
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 14.sp,
                  color: const Color(0xFFEA580C),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: PageUpTextTicker(
                    items: topMenuItemNames.isNotEmpty
                        ? topMenuItemNames
                        : [
                            if (restaurant.featuredDishName != null)
                              '${restaurant.featuredDishName}${startingPrice > 0 ? ' • ₹${startingPrice.toStringAsFixed(0)}' : ''}'
                          ],
                    prefix: Text(
                      'Must Try • ',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFC2410C),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                if (!restaurant.isOpen)
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'Unavailable',
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: () {
                      Haptics.medium();
                      context.push(RouteNames.restaurantDetail,
                          extra: restaurant);
                    },
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: const Color(0xFFFED7AA),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 14.sp,
                            color: const Color(0xFFE65100),
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFE65100),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MediaCarousel extends ConsumerStatefulWidget {
  final RestaurantModel? restaurant;
  final String restaurantId;
  final List<String> imageSlides;
  final bool isOpen;
  final String? featuredPriceBadge;
  final String? featuredDishName;
  final List<String> topMenuItemNames;
  final ValueChanged<int>? onPageChanged;

  const _MediaCarousel({
    this.restaurant,
    required this.restaurantId,
    required this.imageSlides,
    required this.isOpen,
    this.featuredPriceBadge,
    this.featuredDishName,
    this.topMenuItemNames = const [],
    this.onPageChanged,
  });

  @override
  ConsumerState<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends ConsumerState<_MediaCarousel> with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  Timer? _timer;
  Timer? _inactivityTimer;
  int _currentPage = 0;
  bool _isUserInteracting = false;

  late final AnimationController _heartBumpController;
  late final Animation<double> _heartScaleAnimation;

  int get _slideCount => widget.imageSlides.length;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _heartBumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(
      CurvedAnimation(parent: _heartBumpController, curve: Curves.easeOutCubic),
    );

    if (_slideCount > 1) {
      _startAutoSlideTimer();
    }
  }

  @override
  void didUpdateWidget(covariant _MediaCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageSlides.length != widget.imageSlides.length) {
      if (_currentPage >= widget.imageSlides.length) {
        _currentPage = 0;
      }
      if (_slideCount > 1) {
        _startAutoSlideTimer();
      } else {
        _timer?.cancel();
        _inactivityTimer?.cancel();
      }
    }
  }

  void _startAutoSlideTimer() {
    _timer?.cancel();
    if (_slideCount <= 1 || !mounted || _isUserInteracting) return;

    _timer = Timer.periodic(const Duration(milliseconds: 2800), (timer) {
      if (!mounted || _slideCount <= 1 || _isUserInteracting) {
        timer.cancel();
        return;
      }
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _slideCount;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _onUserInteractionStart() {
    _isUserInteracting = true;
    _timer?.cancel();
    _inactivityTimer?.cancel();
  }

  void _onUserInteractionEnd() {
    if (!_isUserInteracting) return;
    _isUserInteracting = false;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isUserInteracting && _slideCount > 1) {
        _startAutoSlideTimer();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _inactivityTimer?.cancel();
    _pageController.dispose();
    _heartBumpController.dispose();
    super.dispose();
  }

  void _handleFavoriteTap() {
    Haptics.medium();
    _heartBumpController.forward(from: 0.0);
    ref.read(favoritesViewModelProvider.notifier).toggle(widget.restaurantId, widget.restaurant);
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref.watch(
      favoritesViewModelProvider.select((state) => state.value?.restaurantIds.contains(widget.restaurantId) ?? false),
    );

    final currentDishLabel = widget.topMenuItemNames.isNotEmpty
        ? widget.topMenuItemNames[_currentPage % widget.topMenuItemNames.length]
        : (widget.featuredDishName != null
            ? '${widget.featuredDishName}${widget.featuredPriceBadge != null ? " • ${widget.featuredPriceBadge}" : ""}'
            : widget.featuredPriceBadge);

    return SizedBox(
      height: 175.h,
      child: Stack(
        children: [
          // 1. Cover / Food Image Slides Carousel (Grayscale desaturation when closed)
          Positioned.fill(
            child: _slideCount == 0
                ? Container(color: const Color(0xFFF0F0F0))
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollStartNotification &&
                          notification.dragDetails != null) {
                        _onUserInteractionStart();
                      } else if (notification is ScrollEndNotification) {
                        _onUserInteractionEnd();
                      }
                      return false;
                    },
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        widget.isOpen ? Colors.transparent : Colors.grey,
                        widget.isOpen ? BlendMode.dst : BlendMode.saturation,
                      ),
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _slideCount,
                        onPageChanged: (page) {
                          setState(() => _currentPage = page);
                          widget.onPageChanged?.call(page);
                        },
                        itemBuilder: (context, index) {
                          return SmartImage(
                            url: widget.imageSlides[index],
                            category: ImageCategory.restaurant,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          );
                        },
                      ),
                    ),
                  ),
          ),

          // 2. Dark Gradient Overlay for text contrast
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // 3. Temporarily Closed Badge Overlay (Matching Screenshot)
          if (!widget.isOpen)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: const Color(0xDC18181B),
                      borderRadius: BorderRadius.circular(22.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 26.sp,
                          color: const Color(0xFFF43F5E),
                        ),
                        SizedBox(width: 10.w),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TEMPORARILY CLOSED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                              ),
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              'Will reopen soon',
                              style: TextStyle(
                                color: const Color(0xFFD4D4D8),
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 4. Synchronized Top-Left Black Tag (Dish Name & Price)
          if (currentDishLabel != null && currentDishLabel.isNotEmpty)
            Positioned(
              top: 12.h,
              left: 12.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.3),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Row(
                    key: ValueKey<String>(currentDishLabel),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 13.sp,
                        color: const Color(0xFFFF7A00),
                      ),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          currentDishLabel,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 5. Bookmark / Favorite Button (Top-Right)
          Positioned(
            top: 12.h,
            right: 12.w,
            child: GestureDetector(
              onTap: _handleFavoriteTap,
              child: Container(
                width: 32.w,
                height: 32.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ScaleTransition(
                  scale: _heartScaleAnimation,
                  child: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 17.sp,
                    color: isFavorite ? const Color(0xFFFF4B72) : Colors.black54,
                  ),
                ),
              ),
            ),
          ),

          // 6. Carousel Dot Indicators (Matching Screenshot)
          if (_slideCount > 1)
            Positioned(
              bottom: 10.h,
              right: 12.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_slideCount, (i) => _dot(i == _currentPage)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dot(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: EdgeInsets.only(left: 4.w),
      width: active ? 14.w : 5.w,
      height: 5.h,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3.r),
      ),
    );
  }
}

/// Animated ticker cycling through items using vertical page-up transition
/// (old text slides UP and exits top, new text arrives UP from bottom).
class PageUpTextTicker extends StatefulWidget {
  final List<String> items;
  final TextStyle style;
  final Widget? prefix;
  final Duration interval;
  final Duration animationDuration;

  const PageUpTextTicker({
    super.key,
    required this.items,
    required this.style,
    this.prefix,
    this.interval = const Duration(milliseconds: 2800),
    this.animationDuration = const Duration(milliseconds: 400),
  });

  @override
  State<PageUpTextTicker> createState() => _PageUpTextTickerState();
}

class _PageUpTextTickerState extends State<PageUpTextTicker> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant PageUpTextTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _currentIndex = 0;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.items.length <= 1) return;
    _timer = Timer.periodic(widget.interval, (timer) {
      if (!mounted || widget.items.length <= 1) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.items.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final currentText = widget.items[_currentIndex % widget.items.length];

    return AnimatedSwitcher(
      duration: widget.animationDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        final isIncoming =
            (child.key as ValueKey<int>?)?.value == _currentIndex;

        final inAnimation = Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(animation);

        final outAnimation = Tween<Offset>(
          begin: const Offset(0.0, -1.0),
          end: Offset.zero,
        ).animate(animation);

        return SlideTransition(
          position: isIncoming ? inAnimation : outAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: Row(
        key: ValueKey<int>(_currentIndex),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.prefix != null) ...[
            widget.prefix!,
            SizedBox(width: 4.w),
          ],
          Flexible(
            child: Text(
              currentText,
              style: widget.style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
