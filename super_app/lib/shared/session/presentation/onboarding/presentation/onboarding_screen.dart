import 'package:superapp_user/core/storage/storage_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:superapp_user/core/storage/storage_keys.dart';

class _OnboardPage {
  final String image;
  final String titlePrefix;
  final String titleSuffix;
  final String description;

  const _OnboardPage({
    required this.image,
    required this.titlePrefix,
    required this.titleSuffix,
    required this.description,
  });
}

const _pages = [
  _OnboardPage(
    image: 'assets/images/taxi/1.png',
    titlePrefix: 'Quick and Reliable',
    titleSuffix: 'Ride Tracking',
    description:
        'Experience our real-time tracking feature to see exactly where your driver is and when they will arrive at your stop.',
  ),
  _OnboardPage(
    image: 'assets/images/taxi/2.png',
    titlePrefix: 'Welcome to',
    titleSuffix: 'SuperTaxi',
    description:
        'Delivering comfort with care, driven by trust solutions to keep you moving everyday.',
  ),
  _OnboardPage(
    image: 'assets/images/taxi/3.png',
    titlePrefix: 'Effortless',
    titleSuffix: 'Payments',
    description:
        'Our integrated digital payment solution makes transactions safe, fast and secure for every ride.',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  void _finish() {
    ref.read(localStorageServiceProvider).settings.put(StorageKeys.onboardingSeen, true);
    context.go('/auth/phone');
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _previous() {
    if (_index > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar (Back Button + Skip Button)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _index > 0
                      ? IconButton(
                          icon: Icon(Icons.arrow_back, color: textPrimary),
                          onPressed: _previous,
                        )
                      : const SizedBox(width: 48),
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // PageView Slider
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: Image.asset(
                                page.image,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              page.titlePrefix,
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              page.titleSuffix,
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF5200),
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              page.description,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textSecondary,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Controls Bar (Indicator Dots & Circular Next Button)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SmoothPageIndicator(
                    controller: _controller,
                    count: _pages.length,
                    effect: WormEffect(
                      dotColor: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      activeDotColor: const Color(0xFFFF5200),
                      dotHeight: 8,
                      dotWidth: 8,
                      spacing: 8,
                    ),
                  ),
                  Material(
                    color: const Color(0xFFFF5200),
                    shape: const CircleBorder(),
                    elevation: 3,
                    shadowColor: const Color(0x40FF5200),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _next,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
