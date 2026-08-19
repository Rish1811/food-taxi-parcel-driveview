import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/core/storage/local_storage_service.dart';

/// Hive-backed local storage: recent searches, saved places, emergency
/// contacts, favourite drivers, settings.
///
/// Lives in `core` rather than inside a module because `design_system` (theme
/// persistence) and several shared features read it — a module may not be
/// imported from either tier.
///
/// Overridden in `main.dart` with an instance opened during bootstrap, because
/// some call sites read boxes synchronously.
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError('localStorageServiceProvider must be overridden');
});
