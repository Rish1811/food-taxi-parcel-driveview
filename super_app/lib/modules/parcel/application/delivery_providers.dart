import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/modules/parcel/data/delivery_repository.dart';
import 'package:superapp_user/modules/parcel/data/models/delivery_model.dart';

final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  return DeliveryRepository(ref.watch(taxiApiClientProvider));
});

final myDeliveriesProvider = FutureProvider.autoDispose<List<DeliveryModel>>((ref) {
  return ref.watch(deliveryRepositoryProvider).listMyDeliveries();
});

const parcelCategories = ['Documents', 'Food', 'Electronics', 'Clothes', 'Gift', 'Other'];
