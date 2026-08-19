class AddressModel {
  final String id;
  final String title;
  final String fullAddress;
  final String type; // 'Home', 'Office', 'Other'
  final bool isDefault;
  final String? contactName;
  final String? contactPhone;

  // Backend fields — the order payload needs the raw parts and GeoJSON, while
  // the saved-address DTO takes flat latitude/longitude. The server converts.
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final double? latitude;
  final double? longitude;

  const AddressModel({
    required this.id,
    required this.title,
    required this.fullAddress,
    required this.type,
    this.isDefault = false,
    this.contactName,
    this.contactPhone,
    this.street = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.latitude,
    this.longitude,
  });

  /// Maps `GET/POST /food/user/addresses`. The response carries every
  /// coordinate representation at once (latitude/longitude, lat/lng, location).
  factory AddressModel.fromApi(Map<String, dynamic> json) {
    final parts = [
      json['street'],
      json['additionalDetails'],
      json['city'],
      json['state'],
      json['zipCode'],
    ].whereType<String>().where((e) => e.trim().isNotEmpty).toList();

    return AddressModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['label'] ?? 'Home').toString(),
      fullAddress: parts.join(', '),
      type: (json['label'] ?? 'Home').toString(),
      isDefault: json['isDefault'] as bool? ?? false,
      contactPhone: json['phone']?.toString(),
      street: (json['street'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      zipCode: (json['zipCode'] ?? '').toString(),
      latitude: _lat(json),
      longitude: _lng(json),
    );
  }

  /// Saved addresses store coordinates **only** as GeoJSON
  /// (`location: { type: 'Point', coordinates: [lng, lat] }`) — the user
  /// schema has no flat `latitude`/`longitude` fields at all. Reading just the
  /// flat keys therefore always yielded null, which meant the order payload
  /// omitted `location`, Mongoose filled in its `type: 'Point'` default with no
  /// coordinates, and the `deliveryAddress.location` 2dsphere index rejected
  /// the insert with "Can't extract geo keys".
  ///
  /// The flat keys are still read first because that is what
  /// [toApiPayload] sends on create (the server converts them), so a
  /// locally-constructed model round-trips correctly.
  static double? _lat(Map<String, dynamic> json) {
    final flat = (json['latitude'] ?? json['lat']) as num?;
    if (flat != null) return flat.toDouble();
    return _geo(json)?.$2;
  }

  static double? _lng(Map<String, dynamic> json) {
    final flat = (json['longitude'] ?? json['lng'] ?? json['lon']) as num?;
    if (flat != null) return flat.toDouble();
    return _geo(json)?.$1;
  }

  /// `(lng, lat)` from a GeoJSON Point, or null when absent/malformed.
  static (double, double)? _geo(Map<String, dynamic> json) {
    final coords = (json['location'] as Map?)?['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    final lng = (coords[0] as num?)?.toDouble();
    final lat = (coords[1] as num?)?.toDouble();
    if (lng == null || lat == null) return null;
    return (lng, lat);
  }

  /// Body for POST/PATCH /food/user/addresses (flat coordinates).
  Map<String, dynamic> toApiPayload() => {
        'label': type,
        'street': street,
        'city': city,
        'state': state,
        'zipCode': zipCode,
        'phone': ?contactPhone,
        'latitude': ?latitude,
        'longitude': ?longitude,
      };

  /// Body for the order payload's `address` (GeoJSON `[lng, lat]`).
  /// Street line for the order API.
  ///
  /// `street` is empty whenever an address was captured from the map picker and
  /// reverse geocoding did not return a structured house/road component. The
  /// full formatted address is a valid street line in that case, and it is far
  /// better than sending `''`.
  String get effectiveStreet =>
      street.trim().isNotEmpty ? street.trim() : fullAddress.trim();

  /// The field stopping this address from being usable for checkout, or null.
  ///
  /// `POST /food/orders` validates `street`, `city` and `state` with
  /// `min(1)`, while `POST /food/orders/calculate` treats all three as
  /// optional. That asymmetry is why a cart can price correctly and then fail
  /// at placement with a bare 400 — worth catching here, with something the
  /// user can act on, rather than firing a request that cannot succeed.
  String? get missingOrderField {
    if (effectiveStreet.isEmpty) return 'street address';
    if (city.trim().isEmpty) return 'city';
    if (state.trim().isEmpty) return 'state';
    // Without coordinates the order document gets a half-formed GeoJSON Point
    // (Mongoose defaults `type: 'Point'`, coordinates stay undefined) and the
    // `deliveryAddress.location` 2dsphere index refuses the insert. A delivery
    // address with no location is also undispatchable, so this is worth
    // blocking on rather than failing at the database.
    if (latitude == null || longitude == null) return 'map location';
    return null;
  }

  bool get isUsableForOrder => missingOrderField == null;

  Map<String, dynamic> toOrderPayload({String? customerName}) => {
        'label': type,
        'name': ?customerName,
        'street': effectiveStreet,
        'city': city.trim(),
        'state': state.trim(),
        'zipCode': zipCode,
        'phone': ?contactPhone,
        if (latitude != null && longitude != null)
          'location': {
            'type': 'Point',
            'coordinates': [longitude, latitude],
          },
      };

  AddressModel copyWith({
    String? id,
    String? title,
    String? fullAddress,
    String? type,
    bool? isDefault,
    String? contactName,
    String? contactPhone,
  }) {
    return AddressModel(
      id: id ?? this.id,
      title: title ?? this.title,
      fullAddress: fullAddress ?? this.fullAddress,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
    );
  }
}
