import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/core/network/api_client.dart';
import 'package:superapp_user/core/storage/token_storage.dart';

/// Encrypted token store — single instance, it caches the pair in memory.
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Bumped when the refresh token is dead and the user must be dropped to guest
/// mode. The auth layer watches this instead of the network layer reaching
/// upward into presentation.
class SessionExpiredNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final sessionExpiredProvider =
    NotifierProvider<SessionExpiredNotifier, int>(SessionExpiredNotifier.new);

/// The one Dio instance for the app.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokens: ref.watch(tokenStorageProvider),
    onSessionExpired: () => ref.read(sessionExpiredProvider.notifier).bump(),
  );
});
