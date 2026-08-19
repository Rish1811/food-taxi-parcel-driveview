import 'package:superapp_user/modules/taxi/ride/data/models/ride_model.dart';
import 'package:superapp_user/modules/parcel/data/models/parcel_model.dart';

class DeliveryModel {
  final RideModel ride;
  final ParcelModel parcel;

  const DeliveryModel({required this.ride, required this.parcel});

  factory DeliveryModel.fromJson(Map<String, dynamic> json) {
    return DeliveryModel(
      ride: RideModel.fromJson(json),
      parcel: json['parcel'] is Map
          ? ParcelModel.fromJson(Map<String, dynamic>.from(json['parcel']))
          : const ParcelModel(),
    );
  }
}
