class VehicleTypeModel {
  final String id;
  final String name;
  final String shortDescription;
  final String description;
  final String transportType;
  final String iconType;
  /// Which delivery card this vehicle appears under in the parcel flow
  /// ('trucks' | '2wheeler' | 'auto' | 'movers'). Empty for taxi vehicles.
  final String deliveryCategory;
  final int capacity;
  final String image;
  final String mapIcon;

  const VehicleTypeModel({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.description,
    required this.transportType,
    required this.iconType,
    this.deliveryCategory = '',
    required this.capacity,
    required this.image,
    required this.mapIcon,
  });

  factory VehicleTypeModel.fromJson(Map<String, dynamic> json) {
    return VehicleTypeModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      shortDescription: (json['short_description'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      transportType: (json['transport_type'] ?? 'taxi').toString(),
      iconType: (json['icon_types'] ?? 'car').toString(),
      deliveryCategory: (json['delivery_category'] ?? '').toString(),
      capacity: int.tryParse('${json['capacity'] ?? 0}') ?? 0,
      image: (json['image'] ?? '').toString(),
      mapIcon: (json['map_icon'] ?? '').toString(),
    );
  }
}
