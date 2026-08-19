import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/core/services/haptic_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'image': 'assets/image/onboard1.png',
      'title': 'Build your\n*Flavor,* Step by Step',
      'subtitle': 'Stack fresh ingredients for meals made your way',
    },
    {
      'image': 'assets/image/onboard2.png',
      'title': 'Delivered in\n*Minutes,* Not Hours',
      'subtitle': 'Enjoy hot meals without the wait.',
    },
    {
      'image': 'assets/image/onboard3.png',
      'title': '*Hot & Fast*\nFood at Your Door',
      'subtitle': 'Order from your favorite Food anytime, anywhere',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticService.selection();
    if (_currentPage < _onboardingData.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/phone-login');
    }
  }

  void _skip() {
    HapticService.selection();
    context.go('/main');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _onboardingData.length,
            itemBuilder: (context, index) {
              return OnboardingContent(
                image: _onboardingData[index]['image']!,
                title: _onboardingData[index]['title']!,
                subtitle: _onboardingData[index]['subtitle']!,
              );
            },
          ),


          // Top Progress Indicators and Skip Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 20.h,
            left: 20.w,
            right: 20.w,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: List.generate(
                    _onboardingData.length,
                    (index) => buildIndicator(index == _currentPage),
                  ),
                ),
                GestureDetector(
                  onTap: _skip,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Button
          Positioned(
            bottom: 40.h,
            left: 20.w,
            right: 20.w,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C1C1E),
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 56.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.r),
                ),
                elevation: 0,
              ),
              child: Text(
                _currentPage == _onboardingData.length - 1
                    ? 'Get Started'
                    : 'Next',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.only(right: 8.w),
      height: 4.h,
      width: 40.w,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(2.r),
      ),
    );
  }
}

class OnboardingContent extends StatelessWidget {
  final String image;
  final String title;
  final String subtitle;

  const OnboardingContent({
    super.key,
    required this.image,
    required this.title,
    required this.subtitle,
  });

  Widget _buildRichTitle(BuildContext context) {
    final theme = Theme.of(context);
    final parts = title.split('*');
    
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: 28.sp,
          fontWeight: FontWeight.bold,
          height: 1.2,
          color: Colors.black,
          fontFamily: theme.textTheme.bodyLarge?.fontFamily,
        ),
        children: parts.asMap().entries.map((entry) {
          int idx = entry.key;
          String text = entry.value;
          bool isHighlighted = idx % 2 != 0;
          return TextSpan(
            text: text,
            style: isHighlighted ? TextStyle(color: theme.primaryColor) : null,
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Image takes up most of the screen
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.75, // extend down
          child: Image.asset(
            image,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),

        // Gradient overlay for smooth transition
        Positioned(
          top: MediaQuery.of(context).size.height * 0.45,
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.0),
                  Colors.white.withOpacity(0.75),
                  Colors.white,
                  Colors.white,
                ],
                stops: const [0.0, 0.15, 0.25, 1.0],
              ),
            ),
          ),
        ),

        // Text Content
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.4,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildRichTitle(context),
                SizedBox(height: 16.h),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 80.h), // Space for the bottom button
              ],
            ),
          ),
        ),
      ],
    );
  }
}
