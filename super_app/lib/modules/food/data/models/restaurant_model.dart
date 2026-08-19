import 'package:flutter/foundation.dart';
import 'package:superapp_user/core/config/api_config.dart';

class RestaurantModel {
  final String id;
  final String name;
  final String imageUrl;
  final List<String> coverImages;
  final List<String> menuImages;
  final double rating;
  final int reviewCount;
  final String deliveryTime;
  final double deliveryFee;
  final List<String> tags;
  final bool isFeatured;
  final double distanceKm;
  final double priceForOne;
  final String? featuredDishName;
  final bool isNearAndFast;
  final List<String> offerBadges;
  final List<String> restaurantTags;
  final bool isOpen;
  final String closingTime;
  final bool isPureVeg;
  final bool isFreeDelivery;
  final String area;

  const RestaurantModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.coverImages = const [],
    this.menuImages = const [],
    required this.rating,
    this.reviewCount = 0,
    required this.deliveryTime,
    required this.deliveryFee,
    required this.tags,
    this.isFeatured = false,
    this.distanceKm = 0.0,
    this.priceForOne = 0.0,
    this.featuredDishName,
    this.isNearAndFast = false,
    this.offerBadges = const [],
    this.restaurantTags = const [],
    this.isOpen = true,
    this.closingTime = '',
    this.isPureVeg = false,
    this.isFreeDelivery = false,
    this.area = '',
  });

  /// Extracts locality / area name from backend restaurant JSON.
  static String _extractLocationFromApi(Map<String, dynamic> json) {
    // 1. Direct String fields for area / locality / locationName
    final directKeys = [
      'area',
      'locality',
      'subLocality',
      'locationName',
      'areaName',
      'outletArea',
      'branchName',
      'neighborhood',
      'vicinity',
    ];

    for (final key in directKeys) {
      final val = json[key];
      if (val is String && val.trim().isNotEmpty) {
        return val.trim();
      }
    }

    // 2. Check if 'location' or 'address' is a Map object
    final mapsToCheck = <Map>[];
    if (json['location'] is Map) mapsToCheck.add(json['location'] as Map);
    if (json['address'] is Map) mapsToCheck.add(json['address'] as Map);

    for (final locMap in mapsToCheck) {
      final mapKeys = [
        'area',
        'locality',
        'subLocality',
        'locationName',
        'areaName',
        'name',
        'addressLine1',
        'street',
        'city',
      ];
      for (final key in mapKeys) {
        final val = locMap[key];
        if (val is String && val.trim().isNotEmpty) {
          return val.trim();
        }
      }
    }

    // 3. Fallback to raw address or location string (e.g. "Shop 12, Main Road, Vijay Nagar, Indore")
    String? rawAddress;
    if (json['address'] is String && (json['address'] as String).trim().isNotEmpty) {
      rawAddress = (json['address'] as String).trim();
    } else if (json['location'] is String && (json['location'] as String).trim().isNotEmpty) {
      rawAddress = (json['location'] as String).trim();
    } else if (json['addressLine1'] is String && (json['addressLine1'] as String).trim().isNotEmpty) {
      rawAddress = (json['addressLine1'] as String).trim();
    } else if (json['city'] is String && (json['city'] as String).trim().isNotEmpty) {
      rawAddress = (json['city'] as String).trim();
    }

    if (rawAddress != null && rawAddress.isNotEmpty) {
      final parts = rawAddress
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (parts.isNotEmpty) {
        if (parts.length == 1) {
          return parts.first;
        } else if (parts.length == 2) {
          return parts.first;
        } else {
          // If e.g. "Shop 101, Main Road, Vijay Nagar, Indore", pick second to last part ("Vijay Nagar")
          return parts[parts.length - 2];
        }
      }
    }

    return '';
  }

  /// Maps a backend restaurant document.
  factory RestaurantModel.fromApi(Map<String, dynamic> json) {
    final image = json['profileImage'];
    final imageUrlRaw = image is Map ? image['url'] as String? : image as String?;
    
    final coversRaw = (json['coverImages'] as List?)
        ?.map((e) => e is Map ? e['url'] as String? : e as String?)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList() ?? const [];

    final resolvedCovers = coversRaw.map((c) => ApiConfig.resolveMedia(c)).toList();

    final menusRaw = (json['menuImages'] as List?)
        ?.map((e) => e is Map ? e['url'] as String? : e as String?)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList() ?? const [];

    final resolvedMenuImages = menusRaw.map((c) => ApiConfig.resolveMedia(c)).toList();

    final primaryImageUrl = ApiConfig.resolveMedia(
      (imageUrlRaw != null && imageUrlRaw.isNotEmpty)
          ? imageUrlRaw
          : (resolvedCovers.isNotEmpty ? resolvedCovers.first : null),
    );

    final offers = <String>[];
    final offer = json['offer'];
    if (offer is String && offer.isNotEmpty) offers.add(offer);
    for (final o in (json['offers'] as List?) ?? const []) {
      if (o is Map && o['title'] is String) {
        offers.add(o['title'] as String);
      } else if (o is String && o.isNotEmpty) {
        offers.add(o);
      }
    }
    if (json['discountText'] is String && (json['discountText'] as String).isNotEmpty) {
      offers.add(json['discountText'] as String);
    }

    final isPureVeg = json['pureVegRestaurant'] == true ||
        json['isVeg'] == true ||
        json['isPureVeg'] == true ||
        json['pureVeg'] == true ||
        json['veg'] == true ||
        json['isVegOnly'] == true ||
        (json['category']?.toString().toLowerCase().contains('veg') == true) ||
        (json['foodType']?.toString().toLowerCase() == 'veg');
    final isFreeDeliv = json['isFreeDelivery'] == true || json['freeDelivery'] == true || (json['deliveryFee'] != null && (json['deliveryFee'] as num).toDouble() == 0.0);
    final areaName = _extractLocationFromApi(json);

    final restId = (json['_id'] ?? json['id'] ?? json['restaurantId'] ?? '').toString();
    final restName = (json['restaurantName'] ?? json['name'] ?? '').toString();

    if (kDebugMode) {
      debugPrint('[RESTAURANT_LOCATION] ID: $restId | Name: $restName | Extracted Location: "$areaName"');
    }

    final isOpen = json['isAcceptingOrders'] as bool? ?? json['isOpen'] as bool? ?? true;
    final closes = (json['closingTime'] ?? json['closesIn'] ?? json['operatingHours'] ?? json['openingTime'] ?? '').toString();
    final featuredDishName = (json['featuredDish'] as String?)?.isNotEmpty == true ? json['featuredDish'] as String : null;

    final priceForOne = (json['featuredPrice'] as num?)?.toDouble() ??
        (json['priceForOne'] as num?)?.toDouble() ??
        (json['startingPrice'] as num?)?.toDouble() ??
        (json['minOrder'] as num?)?.toDouble() ??
        0.0;

    final deliveryTimeStr = (json['estimatedDeliveryTime'] ??
            json['deliveryTime'] ??
            (json['estimatedDeliveryTimeMinutes'] != null ? '${json['estimatedDeliveryTimeMinutes']} mins' : ''))
        .toString();

    return RestaurantModel(
      id: restId,
      name: restName,
      imageUrl: primaryImageUrl,
      coverImages: resolvedCovers.isNotEmpty ? resolvedCovers : (primaryImageUrl.isNotEmpty ? [primaryImageUrl] : const []),
      menuImages: resolvedMenuImages,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['totalRatings'] as num?)?.toInt() ?? (json['reviewCount'] as num?)?.toInt() ?? 0,
      deliveryTime: deliveryTimeStr,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      tags: (json['cuisines'] as List?)?.whereType<String>().toList() ??
            (json['tags'] as List?)?.whereType<String>().toList() ?? const [],
      isFeatured: json['isFeatured'] as bool? ?? false,
      distanceKm: (json['distanceInKm'] as num?)?.toDouble() ??
          ((json['distanceMeters'] as num?)?.toDouble() ?? 0) / 1000,
      priceForOne: priceForOne,
      featuredDishName: featuredDishName,
      isNearAndFast: json['isNearAndFast'] as bool? ?? false,
      offerBadges: offers,
      restaurantTags: [
        if (isPureVeg) 'Pure Veg',
        if (isFreeDeliv) 'Free Delivery',
        if (areaName.isNotEmpty) areaName,
      ],
      isOpen: isOpen,
      closingTime: closes,
      isPureVeg: isPureVeg,
      isFreeDelivery: isFreeDeliv,
      area: areaName,
    );
  }

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    final areaVal = json['area'] as String? ?? _extractLocationFromApi(json);
    return RestaurantModel(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String,
      coverImages: (json['coverImages'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      menuImages: (json['menuImages'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      deliveryTime: json['deliveryTime'] as String? ?? '',
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      isFeatured: json['isFeatured'] as bool? ?? false,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      priceForOne: (json['priceForOne'] as num?)?.toDouble() ?? 0.0,
      featuredDishName: json['featuredDishName'] as String?,
      isNearAndFast: json['isNearAndFast'] as bool? ?? false,
      offerBadges: (json['offerBadges'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      restaurantTags: (json['restaurantTags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      isOpen: json['isOpen'] as bool? ?? true,
      closingTime: json['closingTime'] as String? ?? '',
      isPureVeg: json['isPureVeg'] as bool? ?? false,
      isFreeDelivery: json['isFreeDelivery'] as bool? ?? false,
      area: areaVal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'coverImages': coverImages,
      'menuImages': menuImages,
      'rating': rating,
      'reviewCount': reviewCount,
      'deliveryTime': deliveryTime,
      'deliveryFee': deliveryFee,
      'tags': tags,
      'isFeatured': isFeatured,
      'distanceKm': distanceKm,
      'priceForOne': priceForOne,
      'featuredDishName': featuredDishName,
      'isNearAndFast': isNearAndFast,
      'offerBadges': offerBadges,
      'restaurantTags': restaurantTags,
      'isOpen': isOpen,
      'closingTime': closingTime,
      'isPureVeg': isPureVeg,
      'isFreeDelivery': isFreeDelivery,
      'area': area,
    };
  }
}
