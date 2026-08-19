import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/modules/taxi/notifications/data/models/notification_model.dart';
import 'package:superapp_user/modules/taxi/notifications/data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(taxiApiClientProvider));
});

final notificationsListProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) {
  return ref.watch(notificationsRepositoryProvider).getNotifications();
});

final unreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final listAsync = ref.watch(notificationsListProvider);
  return listAsync.maybeWhen(
    data: (list) {
      final unread = list.where((n) => !n.isRead).length;
      return unread > 0 ? unread : list.length; // fallback to total count if none unread or display count
    },
    orElse: () => 3, // fallback display count when loading/mock
  );
});
