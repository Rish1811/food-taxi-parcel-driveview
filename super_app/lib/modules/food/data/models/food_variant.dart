import 'package:superapp_user/core/config/api_config.dart';

/// A size/portion choice on a menu item.
///
/// The API returns these under `variants`, and duplicates them under the legacy
/// `variations` key — parse whichever is populated, never both.
class FoodVariant {
  final String name;
  final double price;

  /// Struck-through "was" price, when the restaurant set one.
  final double? otherPrice;

  /// The server's id for this variant, sent as `id`/`_id`.
  ///
  /// This used to be assumed absent, and the name was used in its place — but
  /// checkout resolves a variant by matching `_id` against the dish's variant
  /// subdocuments, so a name never matched and every order with a size chosen
  /// was rejected as "no longer available in the selected size". Kept nullable
  /// because a cached model written before this existed has no id to restore.
  final String? serverId;

  const FoodVariant({
    required this.name,
    required this.price,
    this.otherPrice,
    this.serverId,
  });

  /// What checkout must be given. Falls back to the name only when the server
  /// genuinely sent no id, which is the old behaviour and no worse than it.
  String get id => (serverId != null && serverId!.isNotEmpty) ? serverId! : name;

  bool get hasDiscount => otherPrice != null && otherPrice! > price;

  factory FoodVariant.fromApi(Map<String, dynamic> json) {
    final rawId = (json['_id'] ?? json['id'])?.toString().trim();
    return FoodVariant(
      name: (json['name'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      otherPrice: (json['otherPrice'] as num?)?.toDouble(),
      serverId: (rawId == null || rawId.isEmpty) ? null : rawId,
    );
  }

  factory FoodVariant.fromJson(Map<String, dynamic> json) =>
      FoodVariant.fromApi(json);

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'otherPrice': otherPrice,
      'id': serverId,
      '_id': serverId,
    };
  }

  /// Reads `variants`, falling back to the legacy `variations` key.
  static List<FoodVariant> listFrom(Map<String, dynamic> json) {
    final raw = (json['variants'] as List?)?.isNotEmpty == true
        ? json['variants'] as List
        : (json['variations'] as List? ?? const []);
    return raw
        .whereType<Map>()
        .map((e) => FoodVariant.fromApi(e.cast<String, dynamic>()))
        .where((v) => v.name.isNotEmpty)
        .toList();
  }
}

/// A restaurant-level extra from `GET /food/restaurant/restaurants/:id/addons`.
///
/// Add-ons are scoped to the restaurant, not to a single dish — the same list
/// applies to every item on that menu.
class FoodAddon {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final bool isVeg;

  const FoodAddon({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.imageUrl = '',
    this.isVeg = true,
  });

  factory FoodAddon.fromApi(Map<String, dynamic> json) {
    return FoodAddon(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: ApiConfig.resolveMedia(json['image'] as String?),
      // Backend enum is lowercase 'veg' | 'non-veg'.
      isVeg: (json['foodType']?.toString().toLowerCase() ?? 'veg') != 'non-veg',
    );
  }
}

/// What the user picked in the variant sheet.
///
/// Held on the cart line so the same dish with different choices stays a
/// separate line, and so the order payload can carry `variantId` /
/// `variantName` / `variantPrice`.
class FoodSelection {
  final FoodVariant? variant;
  final List<FoodAddon> addons;

  const FoodSelection({this.variant, this.addons = const []});

  static const FoodSelection none = FoodSelection();

  bool get isEmpty => variant == null && addons.isEmpty;

  double get addonTotal => addons.fold(0.0, (sum, a) => sum + a.price);

  /// Unit price for the line: the variant price when one is chosen, otherwise
  /// the item's base price, plus every selected add-on.
  double unitPrice(double basePrice) => (variant?.price ?? basePrice) + addonTotal;

  /// Stable key so two lines with identical choices merge, and different
  /// choices stay separate.
  String signature() {
    final ids = addons.map((a) => a.id).toList()..sort();
    return '${variant?.id ?? ''}|${ids.join(',')}';
  }

  String get summary {
    final parts = <String>[
      if (variant != null) variant!.name,
      ...addons.map((a) => a.name),
    ];
    return parts.join(' • ');
  }
}
