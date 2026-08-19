
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// The "99 Store" promo landing page — a self-contained screen (kept in
/// this single file on purpose) showing the ₹99-meals deal, cuisine
/// filters, trending discounted dishes, and top-brand shortcuts.
///
/// All photography (hero dish/drink images, cuisine thumbnails, dish
/// photos, brand logos) is wired to load from assets/image/store99/ —
/// drop the files in with the names below and they'll render automatically.
/// Until then every image slot falls back to a plain icon so the screen
/// never breaks:
///   assets/image/store99/hero.png                 — bowl + burger + drink hero art
///   assets/image/store99/cuisine_`<id>`.png       — one per _cuisines entry
///   assets/image/store99/dish_`<id>`.png          — one per _dishes entry
///   assets/image/store99/brand_`<id>`.png         — one per _brands entry
class Store99Screen extends StatefulWidget {
  const Store99Screen({super.key});

  @override
  State<Store99Screen> createState() => _Store99ScreenState();
}

class _Store99ScreenState extends State<Store99Screen> {
  String _selectedCuisineId = 'all';

  static const Color _yellow = Color(0xFFFFC72C);
  static const Color _priceGreen = Color(0xFF1FA855);

  static const List<_Cuisine> _cuisines = [
    _Cuisine(id: 'all', label: 'All', icon: Icons.restaurant, imagePath: 'assets/image/all.png'),
    _Cuisine(id: 'biryani', label: 'Biryani', icon: Icons.rice_bowl, imagePath: 'assets/image/birani.png'),
    _Cuisine(id: 'khichdi', label: 'Khichdi', icon: Icons.soup_kitchen, imagePath: 'assets/image/khichidi.png'),
    _Cuisine(id: 'burgers', label: 'Burgers', icon: Icons.lunch_dining, imagePath: 'assets/image/burger.png'),
    _Cuisine(id: 'pizza', label: 'Pizza', icon: Icons.local_pizza, imagePath: 'assets/image/pizza.png'),
  ];

  static const List<_Dish> _dishes = [
    _Dish(
      id: 'aloo_paratha',
      name: 'Aloo Paratha (1 Pc...',
      shop: 'Just Aaloo Par...',
      mrp: 90,
      price: 39,
      rating: 3.8,
      ratingCount: 881,
      icon: Icons.flatware,
      imagePath: 'assets/image/aloopratha.jpg',
    ),
    _Dish(
      id: 'masala_dosa',
      name: 'Masala Dosa',
      shop: 'Ramesh Masa...',
      mrp: 120,
      price: 99,
      rating: 4.2,
      ratingCount: 644,
      icon: Icons.breakfast_dining,
      imagePath: 'assets/image/dosa.jpeg',
    ),
    _Dish(
      id: 'paneer_sandwich',
      name: 'Paneer Masala San...',
      shop: 'Janta Kachori...',
      mrp: 50,
      price: 39,
      rating: 3.5,
      ratingCount: 146,
      icon: Icons.lunch_dining,
      imagePath: 'assets/image/paneersad.jpeg',
    ),
    _Dish(
      id: 'sev_tamatar',
      name: 'Sev Tamatar +...',
      shop: 'The Bansuri...',
      mrp: 159,
      price: 99,
      rating: 4.2,
      ratingCount: 196,
      icon: Icons.dinner_dining,
      imagePath: 'assets/image/sevtomato.jpeg',
    ),
  ];

  static const List<_Dish> _exploreDishes = [
    _Dish(
      id: 'dosa',
      name: 'Masala Dosa',
      shop: 'Ramesh Masala D...',
      mrp: 120,
      price: 99,
      rating: 4.2,
      ratingCount: 644,
      icon: Icons.breakfast_dining,
      imagePath: 'assets/image/dosa.jpeg',
      deliveryTime: '15-20 mins',
    ),
    _Dish(
      id: 'khichdi',
      name: 'Rajbhog Special Thali',
      shop: 'The Rajbhog',
      mrp: 249,
      price: 129,
      rating: 3.7,
      ratingCount: 66,
      icon: Icons.lunch_dining,
      imagePath: 'assets/image/khichidi.png',
      deliveryTime: '20-25 mins',
    ),
    _Dish(
      id: 'aloo_paratha',
      name: 'Ghar Jaisi Thali',
      shop: 'Siddhivinayak Bh...',
      mrp: 307,
      price: 149,
      rating: 4.2,
      ratingCount: 269,
      icon: Icons.lunch_dining,
      imagePath: 'assets/image/aloopratha.jpg',
      deliveryTime: '35-40 mins',
    ),
    _Dish(
      id: 'combo_3',
      name: 'Combo 3',
      shop: 'Just Aaloo Paratha',
      mrp: 259,
      price: 139,
      rating: 3.6,
      ratingCount: 527,
      icon: Icons.flatware,
      imagePath: 'assets/image/sevtomato.jpeg',
      deliveryTime: '25-30 mins',
    ),
    _Dish(
      id: 'sandwich',
      name: 'High Protein Sandwich',
      shop: 'Fit Bite',
      mrp: 199,
      price: 99,
      rating: 4.5,
      ratingCount: 120,
      icon: Icons.lunch_dining,
      imagePath: 'assets/image/paneersad.jpeg',
      deliveryTime: '10-15 mins',
    ),
    _Dish(
      id: 'burger',
      name: 'Chicken Burger',
      shop: 'Burger Lounge',
      mrp: 149,
      price: 89,
      rating: 4.1,
      ratingCount: 211,
      icon: Icons.lunch_dining,
      imagePath: 'assets/image/burger.png',
      deliveryTime: '15-20 mins',
    ),
  ];

  static const List<_Brand> _brands = [
    _Brand(id: 'haldirams', label: "Haldiram's...", icon: Icons.storefront),
    _Brand(id: 'kfc', label: 'KFC', icon: Icons.set_meal),
    _Brand(id: 'burger_farm', label: 'Burger Farm', icon: Icons.lunch_dining),
    _Brand(
      id: 'bikkgane_biryani',
      label: 'Bikkgane Biry...',
      icon: Icons.rice_bowl,
    ),
    _Brand(id: 'rollsking', label: 'Rollsking', icon: Icons.fastfood),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 90.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    SizedBox(height: 10.h),
                    _buildSectionTitle('Popular Cuisines'),
                    SizedBox(height: 16.h),
                    _buildCuisines(),
                    SizedBox(height: 28.h),
                    _buildSectionTitle('Trending dishes near you'),
                    SizedBox(height: 16.h),
                    _buildDishes(),
                    SizedBox(height: 28.h),
                    _buildSectionTitle('Big Savings with Top Brands'),
                    SizedBox(height: 16.h),
                    _buildBrands(),
                    SizedBox(height: 32.h),
                    _buildExploreGrid(),
                    SizedBox(height: 20.h),
                    Center(
                      child: ElevatedButton(
                        onPressed: () => context.push('/restaurant'),
                        child: const Text('View Restaurant Menu Demo'),
                      ),
                    ),
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ==================== HEADER ====================

  Widget _buildHeader(BuildContext context) {
    return ClipRect(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            
            width: double.infinity,
            //height: 250,
            child: Image.asset( 
              'assets/image/new.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8.h,
            left: 12.w,
            child: _buildCircleIconButton(
              icon: Icons.arrow_back,
              onTap: () => context.pop(),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8.h,
            right: 12.w,
            child: _buildCircleIconButton(icon: Icons.search, onTap: () {}),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.r,
        height: 40.r,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20.sp),
      ),
    );
  }



  // ==================== SECTIONS ====================

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1E1E1E),
        ),
      ),
    );
  }

  Widget _buildCuisines() {
    return SizedBox(
      height: 96.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        itemCount: _cuisines.length,
        separatorBuilder: (_, _) => SizedBox(width: 10.w),
        itemBuilder: (context, index) {
          final cuisine = _cuisines[index];
          final isSelected = cuisine.id == _selectedCuisineId;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCuisineId = cuisine.id;
              });
            },
            child: Column(
              children: [ 
                Container(
                  padding: EdgeInsets.all(3.r),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: const Color(0xFFFF7622), width: 2)
                        : null,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none, 
                    children: [
                      _placeholderImage(
                        assetPath: cuisine.imagePath,
                        fallbackIcon: cuisine.icon,
                        height: 64.r,
                        width: 64.r,
                        shape: BoxShape.circle,
                        background: const Color.fromARGB(0, 245, 245, 245),
                        iconColor: const Color.fromARGB(0, 102, 102, 102),
                        fit: BoxFit.contain,
                      ),
                      if (isSelected)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: EdgeInsets.all(2.r),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF7622),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 10.sp,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  cuisine.label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFFFF7622)
                        : const Color(0xFF444444),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDishes() {
    return SizedBox(
      height: 250.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        itemCount: _dishes.length,
        separatorBuilder: (_, _) => SizedBox(width: 14.w),
        itemBuilder: (context, index) => _buildDishCard(_dishes[index]),
      ),
    );
  }

  Widget _buildDishCard(_Dish dish) {
    return SizedBox(
      width: 115.w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _placeholderImage(
                assetPath: dish.imagePath,
                fallbackIcon: dish.icon,
                height: 115.w,
                width: 115.w,
                borderRadius: BorderRadius.circular(16.r),
                background: const Color(0xFFF0F0F0),
                iconColor: const Color(0xFF999999),
              ),
              Positioned(
                right: 4.w,
                bottom: -8.h,
                child: Container(
                  width: 28.r,
                  height: 28.r,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.add, color: _priceGreen, size: 18.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 32.h,
            child: Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(right: 4.w),
                      child: _buildVegIcon(size: 10),
                    ),
                  ),
                  TextSpan(text: dish.name),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E1E1E),
                height: 1.2,
              ),
            ),
          ),
          //SizedBox(height: 4.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '₹${dish.mrp}',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey[500],
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              SizedBox(width: 6.w),
              _buildPriceTag(dish.price, fontSize: 11),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: _priceGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: _priceGreen, size: 10.sp),
                SizedBox(width: 2.w),
                Text(
                  '${dish.rating} (${dish.ratingCount})',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: _priceGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Divider(color: Colors.grey.shade300, height: 1, thickness: 1),
          SizedBox(height: 6.h),
          Text(
            dish.shop,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.sp, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildBrands() {
    return SizedBox(
      height: 90.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        itemCount: _brands.length,
        separatorBuilder: (_, _) => SizedBox(width: 20.w),
        itemBuilder: (context, index) {
          final brand = _brands[index];
          return Column(
            children: [
              _placeholderImage(
                assetPath: 'assets/image/store99/brand_${brand.id}.png',
                fallbackIcon: brand.icon,
                height: 56.r,
                width: 56.r,
                shape: BoxShape.circle,
                background: const Color(0xFFF5F5F5),
                iconColor: const Color(0xFF666666),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              SizedBox(height: 6.h),
              Text(
                brand.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: const Color(0xFF444444),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExploreGrid() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: _exploreDishes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16.w,
          mainAxisSpacing: 24.h,
          childAspectRatio: 0.62,
        ),
        itemBuilder: (context, index) {
          return _buildGridDishCard(_exploreDishes[index]);
        },
      ),
    );
  }

  Widget _buildGridDishCard(_Dish dish) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            _placeholderImage(
              assetPath: dish.imagePath,
              fallbackIcon: dish.icon,
              height: 140.h,
              width: double.infinity,
              borderRadius: BorderRadius.circular(16.r),
              background: const Color(0xFFF0F0F0),
              iconColor: const Color(0xFF999999),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: _buildVegIcon(size: 12),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Text(
                dish.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
            ),
            SizedBox(width: 4.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: _priceGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: _priceGreen, size: 10.sp),
                  SizedBox(width: 2.w),
                  Text(
                    '${dish.rating} (${dish.ratingCount})',
                    style: TextStyle(fontSize: 10.sp, color: _priceGreen, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${dish.mrp}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[500],
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                SizedBox(height: 2.h),
                _buildPriceTag(dish.price, fontSize: 12),
              ],
            ),
            const Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                'ADD',
                style: TextStyle(
                  color: _priceGreen,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                dish.shop,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
            ),
            if (dish.deliveryTime != null)
              Text(
                dish.deliveryTime!,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
          ],
        ),
      ],
    );
  }

  // ==================== BOTTOM NAV ====================

  Widget _buildBottomNav() {
    return Container(
      padding: EdgeInsets.only(top: 10.h, bottom: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(icon: Icons.ramen_dining_outlined, label: 'Food'),
            _buildNavItem(
              icon: Icons.bolt_outlined,
              label: 'Bolt',
              badgeText: '15 MIN',
              badgeColor: const Color(0xFFFF6464),
            ),
            _buildNavItem(
              icon: Icons.storefront,
              label: '99 store',
              selected: true,
            ),
            _buildNavItem(
              icon: Icons.favorite_border,
              label: 'EatRight',
              badgeText: 'NEW',
              badgeColor: const Color(0xFFFF6464),
            ),
            _buildNavItem(
              icon: Icons.replay_circle_filled_outlined,
              label: 'Reorder',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    bool selected = false,
    String? badgeText,
    Color? badgeColor,
  }) {
    final color = selected ? const Color(0xFFFF7622) : Colors.grey[600];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: color, size: 22.sp),
            if (badgeText != null)
              Positioned(
                top: -8.h,
                right: -18.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 7.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // ==================== SHARED HELPERS ====================

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

  Widget _buildPriceTag(int price, {double fontSize = 11}) {
    return Transform(
      transform: Matrix4.skewX(-0.15),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: _yellow,
          borderRadius: BorderRadius.circular(2.r),
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Transform(
          transform: Matrix4.skewX(0.15),
          child: Text(
            '₹$price',
            style: TextStyle(
              fontSize: fontSize.sp,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholderImage({
    required String assetPath,
    required IconData fallbackIcon,
    required double height,
    double? width,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
    Color background = const Color(0xFFF5F5F5),
    Color iconColor = const Color(0xFF999999),
    double? iconSize,
    BoxBorder? border,
    BoxFit fit = BoxFit.cover,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: background,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? borderRadius : null,
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        assetPath,
        fit: fit,
        // Decode at the displayed size, not the source asset's full
        // resolution — this helper renders repeatedly across several
        // horizontal lists/grids on this screen.
        cacheHeight: (height * MediaQuery.of(context).devicePixelRatio).round(),
        cacheWidth: width != null
            ? (width * MediaQuery.of(context).devicePixelRatio).round()
            : null,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Icon(
            fallbackIcon,
            color: iconColor,
            size: iconSize ?? height * 0.45,
          ),
        ),
      ),
    );
  }
}



class _Cuisine {
  final String id;
  final String label;
  final IconData icon;
  final String imagePath;

  const _Cuisine({
    required this.id,
    required this.label,
    required this.icon,
    required this.imagePath,
  });
}

class _Dish {
  final String id;
  final String name;
  final String shop;
  final int mrp;
  final int price;
  final double rating;
  final int ratingCount;
  final IconData icon;
  final String imagePath;
  final String? deliveryTime;

  const _Dish({
    required this.id,
    required this.name,
    required this.shop,
    required this.mrp,
    required this.price,
    required this.rating,
    required this.ratingCount,
    required this.icon,
    required this.imagePath,
    this.deliveryTime,
  });
}

class _Brand {
  final String id;
  final String label;
  final IconData icon;

  const _Brand({required this.id, required this.label, required this.icon});
}
