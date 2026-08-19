import 'package:superapp_user/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:superapp_user/modules/taxi/home/data/models/saved_address_model.dart';

/// Device-local saved places (Hive).
///
/// Follow-up: food's address book is server-backed (`/food/user/addresses`).
/// These never sync, never survive a reinstall, and dispatch cannot see them.
/// The shared-address pass makes the server authoritative and turns this box
/// into a write-through cache — including a one-time upload of whatever
/// existing taxi users already have stored, which is real user data.
class SavedPlacesNotifier extends Notifier<List<SavedAddressModel>> {
  static const _uuid = Uuid();

  @override
  List<SavedAddressModel> build() => _read();

  List<SavedAddressModel> _read() {
    final box = ref.read(localStorageServiceProvider).savedAddresses;
    return box.values
        .map((e) => SavedAddressModel.fromJson(Map<dynamic, dynamic>.from(e)))
        .toList();
  }

  Future<void> add({
    required String label,
    required String address,
    required double lat,
    required double lng,
    String type = 'other',
  }) async {
    final box = ref.read(localStorageServiceProvider).savedAddresses;
    final model = SavedAddressModel(
      id: _uuid.v4(),
      label: label,
      address: address,
      lat: lat,
      lng: lng,
      type: type,
    );
    await box.put(model.id, model.toJson());
    state = _read();
  }

  Future<void> saveHomeOrWork({
    required String type,
    required String address,
    required double lat,
    required double lng,
  }) async {
    final box = ref.read(localStorageServiceProvider).savedAddresses;
    dynamic existingKey;
    for (final k in box.keys) {
      final val = box.get(k);
      if (val != null &&
          (val['type'] == type ||
              (val['label'] ?? '').toString().toLowerCase() ==
                  type.toLowerCase())) {
        existingKey = k;
        break;
      }
    }

    final id = existingKey != null ? existingKey.toString() : _uuid.v4();
    final model = SavedAddressModel(
      id: id,
      label: type.toLowerCase() == 'home' ? 'Home' : 'Work',
      address: address,
      lat: lat,
      lng: lng,
      type: type.toLowerCase(),
    );
    await box.put(id, model.toJson());
    state = _read();
  }

  Future<void> remove(String id) async {
    final box = ref.read(localStorageServiceProvider).savedAddresses;
    await box.delete(id);
    state = _read();
  }
}

final savedPlacesProvider =
    NotifierProvider<SavedPlacesNotifier, List<SavedAddressModel>>(
  SavedPlacesNotifier.new,
);
