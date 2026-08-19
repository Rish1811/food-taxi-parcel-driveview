import 'package:superapp_user/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/modules/taxi/home/data/models/saved_address_model.dart';

class RecentSearchesNotifier extends Notifier<List<SavedAddressModel>> {
  static const _maxItems = 8;

  @override
  List<SavedAddressModel> build() => _read();

  List<SavedAddressModel> _read() {
    final box = ref.read(localStorageServiceProvider).recentSearches;
    return box.values
        .map((e) => SavedAddressModel.fromJson(Map<dynamic, dynamic>.from(e)))
        .toList()
        .reversed
        .toList();
  }

  Future<void> add({
    required String address,
    required double lat,
    required double lng,
  }) async {
    final box = ref.read(localStorageServiceProvider).recentSearches;
    final id = '${lat}_$lng';
    await box.put(
      id,
      SavedAddressModel(
        id: id,
        label: address,
        address: address,
        lat: lat,
        lng: lng,
      ).toJson(),
    );
    if (box.length > _maxItems) {
      await box.deleteAt(0);
    }
    state = _read();
  }
}

final recentSearchesProvider =
    NotifierProvider<RecentSearchesNotifier, List<SavedAddressModel>>(
  RecentSearchesNotifier.new,
);
