import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationSettingsState {
  final bool orderStatus;
  final bool promoOffers;
  final bool soundAlerts;

  const NotificationSettingsState({
    this.orderStatus = true,
    this.promoOffers = true,
    this.soundAlerts = true,
  });

  NotificationSettingsState copyWith({
    bool? orderStatus,
    bool? promoOffers,
    bool? soundAlerts,
  }) {
    return NotificationSettingsState(
      orderStatus: orderStatus ?? this.orderStatus,
      promoOffers: promoOffers ?? this.promoOffers,
      soundAlerts: soundAlerts ?? this.soundAlerts,
    );
  }
}

final notificationsViewModelProvider = NotifierProvider<NotificationsViewModel, NotificationSettingsState>(() {
  return NotificationsViewModel();
});

class NotificationsViewModel extends Notifier<NotificationSettingsState> {
  @override
  NotificationSettingsState build() {
    return const NotificationSettingsState();
  }

  void toggleOrderStatus(bool val) {
    state = state.copyWith(orderStatus: val);
  }

  void togglePromoOffers(bool val) {
    state = state.copyWith(promoOffers: val);
  }

  void toggleSoundAlerts(bool val) {
    state = state.copyWith(soundAlerts: val);
  }
}
