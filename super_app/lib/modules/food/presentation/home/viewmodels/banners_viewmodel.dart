import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/modules/food/data/models/promo_banner_model.dart';
import 'package:superapp_user/modules/food/application/providers/catalog_providers.dart';

/// Hero banner image URLs from `GET /food/hero-banners/public`.
///
/// Returns an empty list on failure so the header falls back to its video
/// slide rather than showing a broken carousel.
final heroBannersProvider = FutureProvider<List<String>>((ref) async {
  try {
    return await ref.watch(catalogRemoteDataSourceProvider).getHeroBannerImages();
  } catch (_) {
    return const [];
  }
});

/// Admin-uploaded promo banners for the home carousel.
///
/// Returns an empty list on failure, like the hero provider above: the section
/// hides itself when there is nothing to show, so a banner outage costs a strip
/// of the home screen rather than an error state in the middle of it.
final promoBannersProvider = FutureProvider<List<PromoBannerModel>>((ref) async {
  try {
    return await ref.watch(catalogRemoteDataSourceProvider).getPromoBanners();
  } catch (_) {
    return const [];
  }
});
