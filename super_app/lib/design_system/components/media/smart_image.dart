import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

enum ImageCategory { restaurant, food, category, brand }

class SmartImage extends StatelessWidget {
  final String url;
  final ImageCategory category;
  final BoxFit fit;
  final double? width;
  final double? height;

  const SmartImage({
    super.key,
    required this.url,
    required this.category,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _placeholder();
    }

    final dpr = MediaQuery.of(context).devicePixelRatio;
    final hasFiniteWidth = width != null && width!.isFinite;
    final hasFiniteHeight = height != null && height!.isFinite;
    final cacheWidth = hasFiniteWidth ? (width! * dpr).round() : null;
    final cacheHeight = hasFiniteHeight ? (height! * dpr).round() : null;

    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: cacheWidth,
        memCacheHeight: cacheHeight,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (context, url) => _skeleton(context),
        errorWidget: (context, url, error) => _placeholder(),
      );
    }

    return Image.asset(
      url,
      fit: fit,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _skeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      color: isDark ? const Color(0xFF242424) : const Color(0xFFF2F2F2),
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFFFE9D6),
      alignment: Alignment.center,
      child: Icon(
        category == ImageCategory.food ? Icons.restaurant_rounded : Icons.storefront_rounded,
        color: const Color(0xFFFF7A00).withValues(alpha: 0.6),
        size: (width != null && width! < 40) ? width! * 0.6 : 28,
      ),
    );
  }
}
