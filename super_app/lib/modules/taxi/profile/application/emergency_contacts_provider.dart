import 'package:superapp_user/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:superapp_user/modules/taxi/profile/data/models/emergency_contact_model.dart';

/// Device-local emergency contacts (Hive).
///
/// Follow-up: k9 now exposes `/api/v1/taxi/safety/trusted-contacts` (GET, POST,
/// PUT, DELETE), which is server-backed and reachable by dispatch during an SOS.
/// This local box should become a cache over that endpoint — contacts that only
/// exist on the handset are of limited use in an actual emergency.
class EmergencyContactsNotifier extends Notifier<List<EmergencyContactModel>> {
  static const _uuid = Uuid();

  @override
  List<EmergencyContactModel> build() => _read();

  List<EmergencyContactModel> _read() {
    final box = ref.read(localStorageServiceProvider).emergencyContacts;
    return box.values
        .map((e) => EmergencyContactModel.fromJson(Map<dynamic, dynamic>.from(e)))
        .toList();
  }

  Future<void> add({
    required String name,
    required String phone,
    String relation = 'Other',
  }) async {
    final box = ref.read(localStorageServiceProvider).emergencyContacts;
    final model = EmergencyContactModel(
      id: _uuid.v4(),
      name: name,
      phone: phone,
      relation: relation,
    );
    await box.put(model.id, model.toJson());
    state = _read();
  }

  Future<void> remove(String id) async {
    final box = ref.read(localStorageServiceProvider).emergencyContacts;
    await box.delete(id);
    state = _read();
  }
}

final emergencyContactsProvider =
    NotifierProvider<EmergencyContactsNotifier, List<EmergencyContactModel>>(
  EmergencyContactsNotifier.new,
);
