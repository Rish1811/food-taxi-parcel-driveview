import 'package:superapp_user/core/config/api_config.dart';

/// One line item on a placed order.
class OrderItem {
  final String itemId;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final bool isVeg;
  final List<String> variants;
  final List<String> addons;
  final String cookingInstructions;
  final String specialNotes;

  const OrderItem({
    required this.itemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl = '',
    this.isVeg = false,
    this.variants = const [],
    this.addons = const [],
    this.cookingInstructions = '',
    this.specialNotes = '',
  });

  /// This line's contribution to the bill — never re-derive `price * quantity`
  /// at call sites, so every screen agrees on the same number.
  double get lineTotal => price * quantity;

  /// A variant/add-on list entry as either a bare name string or `{name,
  /// price, ...}` — never `.toString()` a raw Map, which renders as
  /// "Instance of 'Map'"/`{name: ..., price: ...}` garbage in the UI.
  static String _optionName(Object? entry) {
    if (entry is Map) return (entry['name'] ?? entry['title'] ?? '').toString();
    return entry.toString();
  }

  factory OrderItem.fromApi(Map<String, dynamic> json) {
    return OrderItem(
      itemId: (json['itemId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      imageUrl: ApiConfig.resolveMedia(json['image'] as String?),
      isVeg: json['isVeg'] as bool? ?? false,
      variants:
          ((json['variants'] ?? json['selectedVariants']) as List?)
              ?.map(_optionName)
              .where((n) => n.isNotEmpty)
              .toList() ??
          const [],
      addons:
          ((json['addons'] ?? json['selectedAddons']) as List?)
              ?.map(_optionName)
              .where((n) => n.isNotEmpty)
              .toList() ??
          const [],
      cookingInstructions: (json['cookingInstructions'] ?? '').toString(),
      specialNotes: (json['specialNotes'] ?? '').toString(),
    );
  }
}

/// One entry of the order's audit trail.
class OrderStatusEvent {
  final DateTime? at;
  final String byRole;
  final String from;
  final String to;
  final String note;

  const OrderStatusEvent({
    this.at,
    this.byRole = '',
    this.from = '',
    this.to = '',
    this.note = '',
  });

  factory OrderStatusEvent.fromApi(Map<String, dynamic> json) {
    final raw = json['at']?.toString();
    return OrderStatusEvent(
      at: raw == null ? null : DateTime.tryParse(raw),
      byRole: (json['byRole'] ?? '').toString(),
      from: (json['from'] ?? '').toString(),
      to: (json['to'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
    );
  }
}

/// One stage in the dynamic order timeline the tracking screen renders.
class OrderStage {
  final String status;
  final String label;
  final bool isCompleted;
  final bool isCurrent;
  final DateTime? at;

  const OrderStage({
    required this.status,
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
    this.at,
  });

  bool get isReached => isCompleted || isCurrent;
}

/// `order.eta` from `GET /food/orders/:id` — recomputed server-side from the
/// rider's live position (distance-based, not a Directions call, so it's
/// cheap to poll/refresh on every read).
class OrderEta {
  final int? minutes;
  final double? distanceKm;

  /// `live` (from rider GPS) | `estimate` (no GPS yet) | `completed` | `unavailable`.
  final String source;

  /// `restaurant` — rider still collecting the food; `customer` — rider has
  /// it and is on the way to you.
  final String? target;

  const OrderEta({
    this.minutes,
    this.distanceKm,
    this.source = 'unavailable',
    this.target,
  });

  factory OrderEta.fromApi(Map<String, dynamic>? json) {
    if (json == null) return const OrderEta();
    return OrderEta(
      minutes: (json['minutes'] as num?)?.toInt(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      source: (json['source'] ?? 'unavailable').toString(),
      target: json['target']?.toString(),
    );
  }
}

/// The rider assigned to an order.
class DeliveryPartner {
  final String id;
  final String name;
  final String phone;
  final double rating;

  /// Absolute photo URL. The single-order read populates `profileImage`/`avatar`
  /// on the rider; the list read does not, so this can be empty.
  final String photoUrl;

  /// Aggregate ratings count — the only "experience" figure the backend
  /// exposes (there is no total-deliveries field).
  final int totalRatings;

  /// Vehicle fields. Not yet populated by the order read (BACKEND_CHANGES
  /// P1.1) — empty until the backend selects them, so the UI shows a
  /// "Backend implementation pending" badge instead of a blank row.
  final String vehicleType;
  final String vehicleNumber;

  const DeliveryPartner({
    required this.id,
    required this.name,
    required this.phone,
    this.rating = 0,
    this.photoUrl = '',
    this.totalRatings = 0,
    this.vehicleType = '',
    this.vehicleNumber = '',
  });

  bool get hasPhone => phone.trim().isNotEmpty;
  bool get hasVehicleInfo =>
      vehicleType.trim().isNotEmpty || vehicleNumber.trim().isNotEmpty;

  factory DeliveryPartner.fromApi(Map<String, dynamic> json) {
    final image =
        json['profileImage'] ?? json['profilePhoto'] ?? json['avatar'];
    final imageUrl = image is Map ? image['url'] as String? : image as String?;
    return DeliveryPartner(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? json['fullName'] ?? '').toString(),
      phone: (json['phone'] ?? json['phoneNumber'] ?? '').toString(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      photoUrl: ApiConfig.resolveMedia(imageUrl),
      totalRatings: (json['totalRatings'] as num?)?.toInt() ?? 0,
      vehicleType: (json['vehicleType'] ?? json['vehicleName'] ?? '')
          .toString(),
      vehicleNumber: (json['vehicleNumber'] ?? '').toString(),
    );
  }
}

/// A placed order, normalized from every `/food/orders` endpoint.
///
/// Three independent status axes exist and answer different questions:
///  * [orderStatus]   — the order's lifecycle (drives the stepper)
///  * [currentPhase]  — the rider's leg (drives map copy)
///  * [dispatchStatus] — whether a rider is assigned at all
/// Parses a money value from the API.
///
/// Tolerates a numeric string as well as a number: `as num?` returns null for
/// "70", which would zero a real charge and hide it from the bill.
double _money(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

class OrderModel {
  final String id;
  final String orderNumber;
  final String orderStatus;
  final String currentPhase;
  final String dispatchStatus;

  final String restaurantId;
  final String restaurantName;
  final String restaurantImage;
  final String restaurantAddress;
  final double restaurantRating;
  final bool restaurantIsOpen;
  final bool restaurantIsVerified;

  final List<OrderItem> items;
  final double total;
  final double itemTotal;
  final double addonTotal;
  final double packingCharge;
  final double platformFee;
  final double deliveryCharge;
  final double taxes;

  /// The two components of [taxes], kept apart so each row can name the rate it
  /// was charged at. A single merged figure cannot: the food and the delivery
  /// fee are taxed at different rates.
  final double itemGst;
  final double itemGstRate;
  final double deliveryFeeGst;
  final double deliveryFeeGstRate;

  /// True once the server sends the split. Orders placed before it did only
  /// carry the merged [taxes], which must still be shown as one row.
  bool get hasSplitGst => itemGst > 0 || deliveryFeeGst > 0;
  final double couponDiscount;
  final double walletUsed;
  final double rewardDiscount;
  final double driverTip;
  final String currency;

  final String paymentMethod;
  final String paymentStatus;
  final String refundStatus;
  final String transactionId;
  final DateTime? paymentTime;
  final double refundAmount;

  final DeliveryPartner? deliveryPartner;
  final double? riderLat;
  final double? riderLng;
  final double? restaurantLat;
  final double? restaurantLng;
  final double? dropLat;
  final double? dropLng;

  final double? roadDistanceKm;
  final int? roadDurationMins;
  final OrderEta eta;

  final bool dropOtpRequired;
  final bool dropOtpVerified;

  final List<OrderStatusEvent> statusHistory;
  final String cancellationReason;
  final String cancelledBy;

  final DateTime? createdAt;
  final DateTime? deliveredAt;

  /// When the restaurant's acceptance window closes — the only backend signal
  /// for "estimated confirmation time" while the order sits in `created`.
  final DateTime? acceptanceDeadlineAt;

  final String deliveryAddress;
  final String customerName;
  final String customerPhone;
  final String landmark;

  final double foodRating;
  final double deliveryRating;
  final String foodRatingComment;
  final String deliveryRatingComment;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.orderStatus,
    this.currentPhase = '',
    this.dispatchStatus = '',
    this.restaurantId = '',
    this.restaurantName = '',
    this.restaurantImage = '',
    this.restaurantAddress = '',
    this.restaurantRating = 0.0,
    this.restaurantIsOpen = false,
    this.restaurantIsVerified = false,
    this.items = const [],
    this.total = 0,
    this.itemTotal = 0,
    this.addonTotal = 0,
    this.packingCharge = 0,
    this.platformFee = 0,
    this.deliveryCharge = 0,
    this.taxes = 0,
    this.itemGst = 0,
    this.itemGstRate = 0,
    this.deliveryFeeGst = 0,
    this.deliveryFeeGstRate = 0,
    this.couponDiscount = 0,
    this.walletUsed = 0,
    this.rewardDiscount = 0,
    this.driverTip = 0,
    this.currency = 'INR',
    this.paymentMethod = '',
    this.paymentStatus = '',
    this.refundStatus = 'none',
    this.transactionId = '',
    this.paymentTime,
    this.refundAmount = 0,
    this.deliveryPartner,
    this.riderLat,
    this.riderLng,
    this.restaurantLat,
    this.restaurantLng,
    this.dropLat,
    this.dropLng,
    this.roadDistanceKm,
    this.roadDurationMins,
    this.eta = const OrderEta(),
    this.dropOtpRequired = false,
    this.dropOtpVerified = false,
    this.statusHistory = const [],
    this.cancellationReason = '',
    this.cancelledBy = '',
    this.createdAt,
    this.deliveredAt,
    this.acceptanceDeadlineAt,
    this.deliveryAddress = '',
    this.customerName = '',
    this.customerPhone = '',
    this.landmark = '',
    this.foodRating = 0.0,
    this.deliveryRating = 0.0,
    this.foodRatingComment = '',
    this.deliveryRatingComment = '',
  });

  static const _activeStatuses = {
    'pending',
    'placed',
    'created',
    'waiting',
    'accepted',
    'confirmed',
    'preparing',
    'ready',
    'ready_for_pickup',
    'reached_pickup',
    'picked_up',
    'out_for_delivery',
    'en_route_to_delivery',
    'reached_drop',
    'at_drop',
    'arriving_soon',
  };

  static const _terminal = {
    'delivered',
    'completed',
    'cancelled',
    'cancelled_by_user',
    'cancelled_by_restaurant',
    'cancelled_by_admin',
    'rejected',
    'failed',
    'expired',
    'pending_payment',
  };

  /// A restaurant rating is required to submit, so its presence alone marks
  /// the order as rated — `PATCH .../ratings` rejects a second submission.
  bool get hasRated => foodRating > 0;

  /// The bill's "Item Total" row: the backend-computed subtotal, falling back
  /// to summing item lines only for the rare order predating that field.
  /// Single source of truth — every bill/summary screen reads this instead of
  /// re-deriving it.
  double get effectiveItemTotal => itemTotal > 0
      ? itemTotal
      : items.fold<double>(0, (sum, item) => sum + item.lineTotal);

  bool get isActive =>
      _activeStatuses.contains(orderStatus) ||
      (orderStatus.isNotEmpty && !_terminal.contains(orderStatus));
  bool get isCancelled => orderStatus.startsWith('cancelled');
  bool get isDelivered => orderStatus == 'delivered';

  /// True while the order sits with the restaurant, before it has accepted or
  /// rejected — the "waiting for confirmation" phase.
  bool get isAwaitingAcceptance => orderStatus == 'created';

  /// "Usually confirmed within Xm Ys", derived from the backend's own
  /// acceptance window — never a guessed number.
  String? get confirmationEtaLabel {
    final deadline = acceptanceDeadlineAt;
    if (!isAwaitingAcceptance || deadline == null) return null;
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) return 'Confirming any moment now';
    final mins = remaining.inMinutes;
    final secs = remaining.inSeconds % 60;
    if (mins <= 0) return 'Confirming within ${secs}s';
    return 'Usually confirmed within ${mins}m ${secs}s';
  }

  /// The backend rejects cancellation once the food is on its way.
  bool get canCancel =>
      isActive &&
      const {'created', 'confirmed', 'preparing'}.contains(orderStatus);

  bool get hasRider => deliveryPartner != null && dispatchStatus == 'accepted';
  bool get showDropOtp => dropOtpRequired && !dropOtpVerified;

  /// The live map is shown only once the food is on its way — i.e. after the
  /// rider has picked it up, per the tracking spec. Derived from both status
  /// axes so either advancing turns it on.
  bool get isOutForDelivery =>
      const {'picked_up', 'reached_drop'}.contains(orderStatus) ||
      const {'en_route_to_delivery', 'at_drop'}.contains(currentPhase);

  /// Human-readable stage label. Kept here so list, detail and tracking all
  /// render the same wording.
  String get statusLabel {
    switch (orderStatus) {
      case 'pending_payment':
        return 'Awaiting payment';
      case 'created':
        return 'Order placed';
      case 'confirmed':
        return 'Confirmed';
      case 'preparing':
        return 'Preparing your food';
      case 'ready_for_pickup':
        return 'Ready for pickup';
      case 'reached_pickup':
        return 'Rider at restaurant';
      case 'picked_up':
        return 'On the way';
      case 'reached_drop':
        return 'Rider has arrived';
      case 'delivered':
        return 'Delivered';
      case 'cancelled_by_user':
        return 'Cancelled by you';
      case 'cancelled_by_restaurant':
        return 'Cancelled by restaurant';
      case 'cancelled_by_admin':
        return 'Cancelled';
      default:
        return orderStatus;
    }
  }

  /// Live ETA line, e.g. "Arriving in 18 mins" — recomputed server-side from
  /// the rider's live position on every order read (see [OrderEta]). Falls
  /// back to the older pricing-derived road duration for callers still on a
  /// cached response without an `eta` object. Never invents a number.
  String? get etaLabel {
    if (isDelivered || isCancelled) return null;
    switch (eta.source) {
      case 'live':
      case 'estimate':
        final mins = eta.minutes;
        if (mins == null || mins <= 0) break;
        final verb = eta.target == 'restaurant'
            ? 'Rider reaching restaurant in'
            : 'Arriving in';
        return '$verb $mins min${mins == 1 ? '' : 's'}';
      case 'unavailable':
        return 'Calculating...';
      case 'completed':
        return null;
    }
    final mins = roadDurationMins;
    if (mins == null || mins <= 0) return null;
    return 'Arriving in $mins min${mins == 1 ? '' : 's'}';
  }

  /// A number-first version of [etaLabel] for tight spaces (the floating
  /// active-order card) — "27 min" instead of a full sentence.
  String? get compactEtaLabel {
    if (isDelivered || isCancelled) return null;
    final mins = eta.minutes ?? roadDurationMins;
    if (mins == null || mins <= 0) return null;
    return '$mins min${mins == 1 ? '' : 's'}';
  }

  String? get distanceLabel {
    final km = eta.distanceKm ?? roadDistanceKm;
    if (km == null || km <= 0) return null;
    return '${km.toStringAsFixed(1)} km away';
  }

  /// The order's happy-path lifecycle, in order. Cancellations are terminal and
  /// handled separately, so they are not part of the stepper.
  static const List<String> _lifecycle = [
    'created',
    'confirmed',
    'preparing',
    'ready_for_pickup',
    'reached_pickup',
    'picked_up',
    'reached_drop',
    'delivered',
  ];

  /// A dynamic timeline the UI renders without hardcoding stages.
  ///
  /// Each stage's completion is derived from where [orderStatus] sits in the
  /// lifecycle, and its timestamp (when present) from [statusHistory] — so a
  /// backend that adds a new status still renders in the right place via
  /// [statusLabel], and unknown statuses simply append.
  List<OrderStage> get timeline {
    // Where the current status sits. `pending_payment` maps before `created`.
    final currentIndex = _lifecycle.indexOf(orderStatus);

    DateTime? timeFor(String status) {
      for (final e in statusHistory) {
        if (e.to == status) return e.at;
      }
      return null;
    }

    final stages = <OrderStage>[];
    for (var i = 0; i < _lifecycle.length; i++) {
      final status = _lifecycle[i];
      final reached = currentIndex >= 0 && i <= currentIndex;
      stages.add(
        OrderStage(
          status: status,
          label: _labelFor(status),
          isCompleted: reached && status != orderStatus,
          isCurrent: status == orderStatus,
          at: timeFor(status),
        ),
      );
    }
    return stages;
  }

  static String _labelFor(String status) {
    switch (status) {
      case 'created':
        return 'Order placed';
      case 'confirmed':
        return 'Order confirmed';
      case 'preparing':
        return 'Preparing your food';
      case 'ready_for_pickup':
        return 'Food is ready';
      case 'reached_pickup':
        return 'Rider at restaurant';
      case 'picked_up':
        return 'Order picked up';
      case 'reached_drop':
        return 'Arriving at your door';
      case 'delivered':
        return 'Delivered';
      default:
        return status;
    }
  }

  static double? _coord(dynamic list, int index) {
    if (list is List && list.length > index) {
      return (list[index] as num?)?.toDouble();
    }
    return null;
  }

  factory OrderModel.fromApi(Map<String, dynamic> json) {
    // restaurantId is populated to an object on read, but a bare id elsewhere.
    final restaurant = json['restaurantId'];
    final restaurantMap = restaurant is Map
        ? restaurant.cast<String, dynamic>()
        : const <String, dynamic>{};

    final pricing =
        (json['pricing'] as Map?)?.cast<String, dynamic>() ?? const {};
    final payment =
        (json['payment'] as Map?)?.cast<String, dynamic>() ?? const {};
    final dispatch =
        (json['dispatch'] as Map?)?.cast<String, dynamic>() ?? const {};
    final deliveryState =
        (json['deliveryState'] as Map?)?.cast<String, dynamic>() ?? const {};
    final address =
        (json['deliveryAddress'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ratings =
        (json['ratings'] as Map?)?.cast<String, dynamic>() ?? const {};
    final restaurantRatingMap = (ratings['restaurant'] as Map?)
        ?.cast<String, dynamic>();
    final deliveryRatingMap = (ratings['deliveryPartner'] as Map?)
        ?.cast<String, dynamic>();

    final partner = dispatch['deliveryPartnerId'];
    final currentLocation = (deliveryState['currentLocation'] as Map?)
        ?.cast<String, dynamic>();

    final dropOtp =
        ((json['deliveryVerification'] as Map?)?['dropOtp'] as Map?)
            ?.cast<String, dynamic>() ??
        const {};

    final created = json['createdAt']?.toString();
    final delivered = json['deliveredAt']?.toString();
    final acceptanceDeadline = json['acceptanceDeadlineAt']?.toString();

    return OrderModel(
      id: (json['_id'] ?? json['orderMongoId'] ?? '').toString(),
      orderNumber: (json['order_id'] ?? json['orderId'] ?? '').toString(),
      orderStatus: (json['orderStatus'] ?? json['status'] ?? '').toString(),
      currentPhase: (deliveryState['currentPhase'] ?? '').toString(),
      dispatchStatus: (dispatch['status'] ?? '').toString(),
      restaurantId: (restaurantMap['_id'] ?? restaurant ?? '').toString(),
      restaurantName: (restaurantMap['restaurantName'] ?? '').toString(),
      restaurantImage: ApiConfig.resolveMedia(
        restaurantMap['profileImage'] as String?,
      ),
      restaurantAddress: (restaurantMap['address'] ?? '').toString(),
      restaurantRating: (restaurantMap['rating'] as num?)?.toDouble() ?? 0.0,
      restaurantIsOpen: restaurantMap['isOpen'] as bool? ?? false,
      restaurantIsVerified: restaurantMap['isVerified'] as bool? ?? false,
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => OrderItem.fromApi(e.cast<String, dynamic>()))
          .toList(),
      total: _money(pricing['total']),
      // These read the keys the API ACTUALLY sends.
      //
      // Every one of them was previously looking for a name the server does not
      // use — itemTotal for subtotal, packingCharge for packagingFee,
      // deliveryCharge for deliveryFee, taxes for tax — so each resolved to 0.
      // Only platformFee and total happened to match, which is why a bill would
      // show a real total of 227 above a breakdown that added up to 137, with a
      // charged 70 delivery fee proudly labelled FREE.
      //
      // The legacy names are kept as fallbacks in case any other endpoint or an
      // older cached payload still uses them.
      itemTotal: _money(pricing['subtotal'] ?? pricing['itemTotal']),
      addonTotal: _money(pricing['addonTotal']),
      packingCharge: _money(pricing['packagingFee'] ?? pricing['packingCharge']),
      platformFee: _money(pricing['platformFee']),
      deliveryCharge: _money(pricing['deliveryFee'] ?? pricing['deliveryCharge']),
      // Two separate tax lines server-side: tax on the food, and GST on the
      // delivery fee. Both are charged, so both belong in the tax row rather than
      // silently disappearing from the bill.
      taxes: _money(pricing['tax']) +
          _money(pricing['deliveryFeeGst']) +
          _money(pricing['taxes']),
      itemGst: _money(pricing['tax']),
      itemGstRate: _money(pricing['gstRate']),
      deliveryFeeGst: _money(pricing['deliveryFeeGst']),
      deliveryFeeGstRate: _money(pricing['deliveryFeeGstRate']),
      couponDiscount: _money(pricing['discount'] ?? pricing['couponDiscount']),
      walletUsed: _money(pricing['walletUsed'] ?? pricing['walletDiscount']),
      rewardDiscount: _money(pricing['rewardDiscount']),
      driverTip: _money(
        pricing['tip'] ?? pricing['driverTip'] ?? pricing['deliveryTip'],
      ),
      currency: (pricing['currency'] ?? 'INR').toString(),
      paymentMethod: (payment['method'] ?? '').toString(),
      paymentStatus: (payment['status'] ?? '').toString(),
      refundStatus: ((payment['refund'] as Map?)?['status'] ?? 'none')
          .toString(),
      transactionId: (payment['transactionId'] ?? '').toString(),
      paymentTime: payment['time'] != null
          ? DateTime.tryParse(payment['time'].toString())
          : (payment['createdAt'] != null
                ? DateTime.tryParse(payment['createdAt'].toString())
                : null),
      refundAmount:
          ((payment['refund'] as Map?)?['amount'] as num?)?.toDouble() ?? 0.0,
      deliveryPartner: partner is Map
          ? DeliveryPartner.fromApi(partner.cast<String, dynamic>())
          : null,
      riderLat: (currentLocation?['lat'] as num?)?.toDouble(),
      riderLng: (currentLocation?['lng'] as num?)?.toDouble(),
      // GeoJSON is [lng, lat] everywhere it is stored or returned.
      restaurantLat: _coord(
        (restaurantMap['location'] as Map?)?['coordinates'],
        1,
      ),
      restaurantLng: _coord(
        (restaurantMap['location'] as Map?)?['coordinates'],
        0,
      ),
      dropLat: _coord((address['location'] as Map?)?['coordinates'], 1),
      dropLng: _coord((address['location'] as Map?)?['coordinates'], 0),
      roadDistanceKm: (pricing['roadDistanceKm'] as num?)?.toDouble(),
      roadDurationMins: (pricing['roadDurationMins'] as num?)?.toInt(),
      eta: OrderEta.fromApi((json['eta'] as Map?)?.cast<String, dynamic>()),
      dropOtpRequired: dropOtp['required'] as bool? ?? false,
      dropOtpVerified: dropOtp['verified'] as bool? ?? false,
      statusHistory: ((json['statusHistory'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => OrderStatusEvent.fromApi(e.cast<String, dynamic>()))
          .toList(),
      cancellationReason: (json['cancellationReason'] ?? '').toString(),
      cancelledBy: (json['cancelledBy'] ?? '').toString(),
      createdAt: created == null ? null : DateTime.tryParse(created),
      deliveredAt: delivered == null ? null : DateTime.tryParse(delivered),
      acceptanceDeadlineAt: acceptanceDeadline == null
          ? null
          : DateTime.tryParse(acceptanceDeadline),
      deliveryAddress: [
        address['street'],
        address['city'],
        address['state'],
        address['zipCode'],
      ].whereType<String>().where((e) => e.trim().isNotEmpty).join(', '),
      customerName:
          (json['customerName'] ?? address['name'] ?? address['fullName'] ?? '')
              .toString(),
      customerPhone: (json['customerPhone'] ?? address['phone'] ?? '')
          .toString(),
      landmark: (address['landmark'] ?? '').toString(),
      foodRating: (restaurantRatingMap?['rating'] as num?)?.toDouble() ?? 0.0,
      deliveryRating: (deliveryRatingMap?['rating'] as num?)?.toDouble() ?? 0.0,
      foodRatingComment: (restaurantRatingMap?['comment'] ?? '').toString(),
      deliveryRatingComment: (deliveryRatingMap?['comment'] ?? '').toString(),
    );
  }
}
