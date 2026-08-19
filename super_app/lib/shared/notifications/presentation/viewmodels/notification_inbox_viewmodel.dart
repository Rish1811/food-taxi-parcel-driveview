import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/core/error/failures.dart';
import 'package:superapp_user/shared/wallet/data/wallet_model.dart';
import 'package:superapp_user/shared/profile/application/account_providers.dart';
import 'package:superapp_user/shared/auth/presentation/viewmodels/auth_viewmodel.dart';

/// Paginated notification inbox from `GET /food/notifications/inbox`.
///
/// This endpoint uses the `{ items, pagination }` envelope — different from
/// orders (`{ data, meta }`) and restaurants (flat `total`).
class NotificationInboxState {
  final List<AppNotification> items;
  final int unreadCount;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final int totalPages;

  const NotificationInboxState({
    this.items = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.page = 1,
    this.totalPages = 1,
  });

  bool get hasMore => page < totalPages;
  bool get isEmpty => items.isEmpty && !isLoading && error == null;

  NotificationInboxState copyWith({
    List<AppNotification>? items,
    int? unreadCount,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? page,
    int? totalPages,
    bool clearError = false,
  }) {
    return NotificationInboxState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}

final notificationInboxProvider =
    NotifierProvider<NotificationInboxViewModel, NotificationInboxState>(
  NotificationInboxViewModel.new,
);

class NotificationInboxViewModel extends Notifier<NotificationInboxState> {
  @override
  NotificationInboxState build() {
    ref.listen(authViewModelProvider, (previous, next) {
      if (previous?.value?.id == next.value?.id) return;
      if (next.value == null) {
        state = const NotificationInboxState();
      } else {
        unawaited(refresh());
      }
    });

    if (ref.read(authViewModelProvider).value != null) {
      unawaited(refresh());
    }
    return const NotificationInboxState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await ref.read(accountRemoteDataSourceProvider).getInbox(page: 1);
      state = NotificationInboxState(
        items: result.items,
        unreadCount: result.unreadCount,
        totalPages: result.totalPages,
        page: 1,
      );
    } on Failure catch (f) {
      state = state.copyWith(isLoading: false, error: f.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Could not load notifications.');
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    final next = state.page + 1;
    try {
      final result = await ref.read(accountRemoteDataSourceProvider).getInbox(page: next);
      state = state.copyWith(
        items: [...state.items, ...result.items],
        unreadCount: result.unreadCount,
        page: next,
        totalPages: result.totalPages,
        isLoadingMore: false,
      );
    } on Failure catch (f) {
      state = state.copyWith(isLoadingMore: false, error: f.message);
    } catch (_) {
      state = state.copyWith(isLoadingMore: false, error: 'Could not load more.');
    }
  }

  /// Optimistic: flips locally, then persists. Reverts if the server rejects.
  Future<void> markRead(String id) async {
    final previous = state;
    state = state.copyWith(
      items: [
        for (final n in state.items)
          if (n.id == id)
            AppNotification(
              id: n.id,
              title: n.title,
              message: n.message,
              link: n.link,
              category: n.category,
              isRead: true,
              createdAt: n.createdAt,
            )
          else
            n,
      ],
      unreadCount: (state.unreadCount - 1).clamp(0, 1 << 30),
    );
    try {
      await ref.read(accountRemoteDataSourceProvider).markRead(id);
    } catch (_) {
      state = previous;
    }
  }

  Future<void> remove(String id) async {
    final previous = state;
    state = state.copyWith(items: state.items.where((n) => n.id != id).toList());
    try {
      await ref.read(accountRemoteDataSourceProvider).deleteNotification(id);
    } catch (_) {
      state = previous;
    }
  }

  Future<void> clearAll() async {
    final previous = state;
    state = state.copyWith(items: const [], unreadCount: 0);
    try {
      await ref.read(accountRemoteDataSourceProvider).clearInbox();
    } catch (_) {
      state = previous;
    }
  }

  void clearUnreadCount() {
    state = state.copyWith(unreadCount: 0);
  }
}

/// Unread badge count for the header.
///
/// A derived selector rather than a second fetch — the header rebuilds only
/// when the count itself changes, not on every inbox mutation.
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationInboxProvider.select((s) => s.unreadCount));
});
