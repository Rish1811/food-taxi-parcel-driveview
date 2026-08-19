import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/modules/food/data/models/promo_banner_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/components/media/smart_image.dart';

/// Auto-rotating carousel of admin-uploaded promo banners.
class PromoBannerCarousel extends StatefulWidget {
  const PromoBannerCarousel({super.key, required this.banners});

  final List<PromoBannerModel> banners;

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  static const _rotateEvery = Duration(seconds: 4);

  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  // Set while the user is dragging, so auto-rotation never yanks the page out
  // from under a finger that is mid-swipe.
  bool _userInteracting = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.9);
    _startTimer();
  }

  @override
  void didUpdateWidget(PromoBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The list can shrink on refresh (a banner expiring, an admin deleting one).
    // Without this the timer keeps animating to an index that no longer exists.
    if (widget.banners.length != oldWidget.banners.length) {
      _index = _index.clamp(0, (widget.banners.length - 1).clamp(0, 1 << 30));
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    // One banner cannot rotate, and a repeating timer that always no-ops just
    // wakes the UI thread every few seconds for nothing.
    if (widget.banners.length < 2) return;

    _timer = Timer.periodic(_rotateEvery, (_) {
      if (!mounted || _userInteracting || !_controller.hasClients) return;
      final next = (_index + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openBanner(PromoBannerModel banner) async {
    // `destination` is null for decorative banners AND for links that do not
    // resolve to a real app route — see PromoBannerModel. Nothing to do either
    // way, and no haptic, so an inert banner does not pretend to respond.
    final destination = banner.destination;
    if (destination == null) return;

    Haptics.light();

    if (destination.startsWith('/')) {
      if (mounted) context.push(destination);
      return;
    }

    try {
      await launchUrl(
        Uri.parse(destination),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // A link an admin typed must never surface as a crash on the home screen.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 150.h,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification) _userInteracting = true;
              if (n is ScrollEndNotification) _userInteracting = false;
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.banners.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final banner = widget.banners[i];
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  child: GestureDetector(
                    onTap: () => _openBanner(banner),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.r),
                      child: SmartImage(
                        url: banner.imageUrl,
                        category: ImageCategory.food,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Dots are pointless for a single banner — they would imply there is
        // something else to swipe to.
        if (widget.banners.length > 1) ...[
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                width: active ? 18.w : 6.w,
                height: 6.h,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3.r),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
