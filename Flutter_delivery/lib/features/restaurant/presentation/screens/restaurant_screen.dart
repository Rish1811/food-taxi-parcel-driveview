import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({super.key});

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  static const Color _priceGreen = Color(0xFF1FA855);
  static const Color _darkBg = Color(0xFF10131A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                // Top Section (Black header + overlapping white card)
                _buildTopSection(context),
                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: 80.h),
                    child: Column(
                      children: [
                        SizedBox(height: 12.h),
                        _buildSearchBar(),
                        SizedBox(height: 16.h),
                        _buildFilters(),
                        SizedBox(height: 24.h),
                        _build99TopSection(context),
                        SizedBox(height: 24.h),
                        _buildSectionHeader(),
                        SizedBox(height: 16.h),
                        _buildDishesGrid(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Floating Items Button
            Positioned(
              right: 20.w,
              bottom: 20.h,
              child: _buildFloatingItemsButton(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _darkBg,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36.r),
          bottomRight: Radius.circular(36.r),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10.h,
        left: 16.w,
        right: 16.w,
        bottom: 16.h,
      ),
      child: Column(
        children: [
          // App Bar Area
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Icon(Icons.arrow_back, color: Colors.white, size: 24.sp),
              ),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 1),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_add_alt_1, color: Colors.white, size: 16.sp),
                        SizedBox(width: 6.w),
                        Text(
                          'GROUP ORDER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Icon(Icons.more_vert, color: Colors.white, size: 24.sp),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),
          // White Card
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified, color: const Color(0xFF3366FF), size: 14.sp),
                    SizedBox(width: 4.w),
                    Text(
                      'Swiggy Seal',
                      style: TextStyle(
                        color: const Color(0xFF3366FF),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Magic Wok - Chinese Ka Tadka',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E1E1E),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            '25-30 mins  |  South Tukoganj ▾',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1FA855),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '4.2',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 2.w),
                              Icon(Icons.star, color: Colors.white, size: 12.sp),
                            ],
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '145 ratings',
                          style: TextStyle(
                            fontSize: 9.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                // Dashed line
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        (constraints.constrainWidth() / 8).floor(),
                        (index) => Container(
                          width: 4,
                          height: 1,
                          color: Colors.grey.shade300,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '50% off upto ₹100',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E1E1E),
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'USE SWIGGYIT  |  ABOVE ₹179',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '4/5',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFFF7622),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Container(width: 4.r, height: 4.r, decoration: const BoxDecoration(color: Color(0xFFFF7622), shape: BoxShape.circle)),
                            SizedBox(width: 2.w),
                            Container(width: 4.r, height: 4.r, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
                            SizedBox(width: 2.w),
                            Container(width: 4.r, height: 4.r, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Search for dishes',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.search, color: Colors.grey[600], size: 20.sp),
            SizedBox(width: 12.w),
            Container(width: 1, height: 16.h, color: Colors.grey.shade400),
            SizedBox(width: 12.w),
            Icon(Icons.mic, color: const Color(0xFFFF7622), size: 20.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 36.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: [
          _buildToggleFilter(
            icon: _buildVegIcon(size: 10),
            isActive: false,
          ),
          SizedBox(width: 12.w),
          _buildToggleFilter(
            icon: _buildNonVegIcon(size: 10),
            isActive: false,
          ),
          SizedBox(width: 12.w),
          _buildFilterChip(child: Text('Ratings 4.0+', style: TextStyle(fontSize: 12.sp, color: Colors.grey[800]))),
          SizedBox(width: 12.w),
          _buildFilterChip(child: Text('Buy 1 Get 1', style: TextStyle(fontSize: 12.sp, color: Colors.grey[800]))),
          SizedBox(width: 12.w),
          _buildFilterChip(child: Text('Bestseller', style: TextStyle(fontSize: 12.sp, color: Colors.grey[800]))),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required Widget child}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Buy 1 Get 1 Free (86)',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
              Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Text(
                '1 out of 2 items will be made free. ',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Learn More',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF1E1E1E),
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDishesGrid() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: _dishes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16.w,
          mainAxisSpacing: 24.h,
          childAspectRatio: 0.58,
        ),
        itemBuilder: (context, index) {
          return _buildGridDishCard(_dishes[index]);
        },
      ),
    );
  }

  Widget _buildGridDishCard(_RestaurantDish dish) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              height: 140.h,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                color: const Color(0xFFF0F0F0),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                dish.imagePath,
                fit: BoxFit.cover,
                cacheHeight: (140.h * MediaQuery.of(context).devicePixelRatio).round(),
                errorBuilder: (_, __, ___) => Icon(Icons.fastfood, color: Colors.grey[400], size: 40.sp),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildVegIcon(size: 10),
            SizedBox(width: 4.w),
            Icon(Icons.auto_awesome, color: const Color(0xFF5A4099), size: 10.sp),
            SizedBox(width: 2.w),
            Text(
              'Buy1 Get1',
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF5A4099),
              ),
            ),
            const Spacer(),
            if (dish.rating != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: _priceGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: _priceGreen, size: 9.sp),
                    SizedBox(width: 2.w),
                    Text(
                      '${dish.rating} (${dish.ratingCount})',
                      style: TextStyle(fontSize: 9.sp, color: _priceGreen, fontWeight: FontWeight.w700),
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
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E1E1E),
              height: 1.2,
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '₹${dish.price}',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E1E1E),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _priceGreen.withOpacity(0.3)),
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
      ],
    );
  }

  Widget _buildFloatingItemsButton(BuildContext context) {
    return Container(
      width: 60.r,
      height: 60.r,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/image/menuicon.png',
            width: 20.sp,
            height: 20.sp,
            color: Colors.white,
          ),
          SizedBox(height: 2.h),
          Text(
            'ITEMS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 8.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 99 TOP SECTION ====================

  Widget _build99TopSection(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8FC),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 38.h,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -22.h,
                  left: -16.w,
                  child: Image.asset(
                    'assets/image/99.png',
                    height: 86.h,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Icon(Icons.check_circle, color: const Color(0xFF1E1E1E), size: 16.sp),
              SizedBox(width: 4.w),
              Text(
                'Meals at ₹99 + ',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
              Text(
                'Free Delivery',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                  color: const Color(0xFFFF7622),
                ),
              ),
              const Spacer(),
              Text(
                'View All >',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                  color: const Color(0xFF0080FF),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(
            height: 220.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _top99Dishes.length,
              separatorBuilder: (context, index) => SizedBox(width: 12.w),
              itemBuilder: (context, index) {
                return _buildTop99Card(_top99Dishes[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTop99Card(_Top99Dish dish) {
    return SizedBox(
      width: 96.w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16.r),
                child: Image.asset(
                  dish.image,
                  height: 100.h,
                  width: 96.w,
                  fit: BoxFit.cover,
                  cacheHeight: (100.h * MediaQuery.of(context).devicePixelRatio).round(),
                  cacheWidth: (96.w * MediaQuery.of(context).devicePixelRatio).round(),
                ),
              ),
              Positioned(
                bottom: -8.h,
                right: 8.w,
                child: Container(
                  width: 28.r,
                  height: 28.r,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.add, color: const Color(0xFF1FA855), size: 18.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2.h),
                child: _buildVegIcon(size: 8),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: SizedBox(
                  height: 28.h,
                  child: Text(
                    dish.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E1E1E),
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Text(
                '₹${dish.oldPrice}',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.grey[600],
                  decoration: TextDecoration.lineThrough,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 4.w),
              Transform(
                transform: Matrix4.skewX(-0.1),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Transform(
                    transform: Matrix4.skewX(0.1),
                    child: Text(
                      '₹${dish.newPrice}',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: const Color(0xFFE5F7ED),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: const Color(0xFF1FA855), size: 8.sp),
                SizedBox(width: 2.w),
                Text(
                  dish.rating,
                  style: TextStyle(
                    color: const Color(0xFF1FA855),
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Divider(color: Colors.grey.shade300, height: 1, thickness: 1),
          SizedBox(height: 8.h),
          Text(
            dish.restaurant,
            style: TextStyle(
              fontSize: 9.sp,
              color: Colors.grey[500],
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==================== SHARED HELPERS ====================

  Widget _buildToggleFilter({required Widget icon, required bool isActive}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          SizedBox(width: 6.w),
          Container(
            width: 24.w,
            height: 12.h,
            decoration: BoxDecoration(
              color: isActive ? _priceGreen.withOpacity(0.2) : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10.r),
            ),
            alignment: isActive ? Alignment.centerRight : Alignment.centerLeft,
            padding: EdgeInsets.all(1.5.r),
            child: Container(
              width: 10.r,
              height: 10.r,
              decoration: BoxDecoration(
                color: isActive ? _priceGreen : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2),
                ],
              ),
            ),
          ),
          SizedBox(width: 4.w),
        ],
      ),
    );
  }

  Widget _buildStarburstOfferIcon() {
    return SizedBox(
      width: 28.sp,
      height: 28.sp,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(28.sp, 28.sp),
            painter: _StarburstPainter(color: const Color(0xFFFF7622)),
          ),
          Text(
            '%',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w900,
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

class _RestaurantDish {
  final String id;
  final String name;
  final String imagePath;
  final int price;
  final double? rating;
  final int? ratingCount;

  const _RestaurantDish({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.price,
    this.rating,
    this.ratingCount,
  });
}

class _Top99Dish {
  final String name;
  final String image;
  final int oldPrice;
  final int newPrice;
  final String rating;
  final String restaurant;

  _Top99Dish({
    required this.name,
    required this.image,
    required this.oldPrice,
    required this.newPrice,
    required this.rating,
    required this.restaurant,
  });
}

final List<_Top99Dish> _top99Dishes = [
  _Top99Dish(
    name: 'Masala Dosa',
    image: 'assets/image/dosa.jpeg',
    oldPrice: 120,
    newPrice: 99,
    rating: '4.2 (645)',
    restaurant: 'Ramesh Masa...',
  ),
  _Top99Dish(
    name: 'Paneer Masala Sandwich',
    image: 'assets/image/paneersad.jpeg',
    oldPrice: 50,
    newPrice: 39,
    rating: '3.5 (146)',
    restaurant: 'Janta Kachori...',
  ),
  _Top99Dish(
    name: 'Sev Tamatar + 4 Roti',
    image: 'assets/image/sevtomato.jpeg',
    oldPrice: 159,
    newPrice: 99,
    rating: '4.2 (196)',
    restaurant: 'The Bansuriw...',
  ),
  _Top99Dish(
    name: 'Sweet Corns Pizza',
    image: 'assets/image/burger.png',
    oldPrice: 145,
    newPrice: 99,
    rating: '4.4 (2.1k)',
    restaurant: 'La Pino\'z...',
  ),
];

const List<_RestaurantDish> _dishes = [
  _RestaurantDish(
    id: 'manchurian',
    name: 'Veg Manchurian Dry - 8 Pcs',
    price: 285,
    imagePath: 'assets/image/paneersad.jpeg',
  ),
  _RestaurantDish(
    id: 'chilli_potato',
    name: 'Honey Chilli Potatoes',
    price: 229,
    rating: 4.0,
    ratingCount: 2,
    imagePath: 'assets/image/aloopratha.jpg',
  ),
  _RestaurantDish(
    id: 'fries',
    name: 'Crispy French Fries',
    price: 149,
    rating: 4.5,
    ratingCount: 120,
    imagePath: 'assets/image/sevtomato.jpeg',
  ),
  _RestaurantDish(
    id: 'burger',
    name: 'Chicken Burger Special',
    price: 199,
    imagePath: 'assets/image/burger.png',
  ),
];
