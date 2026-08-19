class SavedAddressModel {
  final String id;
  final String label;
  final String address;
  final double lat;
  final double lng;
  final String type;

  const SavedAddressModel({
    required this.id,
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
    this.type = 'other',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'address': address,
        'lat': lat,
        'lng': lng,
        'type': type,
      };

  factory SavedAddressModel.fromJson(Map<dynamic, dynamic> json) {
    return SavedAddressModel(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      lat: double.tryParse('${json['lat'] ?? 0}') ?? 0,
      lng: double.tryParse('${json['lng'] ?? 0}') ?? 0,
      type: (json['type'] ?? 'other').toString(),
    );
  }
}
