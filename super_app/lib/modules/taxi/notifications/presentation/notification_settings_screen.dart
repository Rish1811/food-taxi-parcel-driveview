import 'package:superapp_user/core/storage/storage_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:superapp_user/design_system/components/ride/custom_app_bar.dart';

class _NotificationPrefKeys {
  static const rideUpdates = 'notif_pref_ride_updates';
  static const promotions = 'notif_pref_promotions';
  static const walletAlerts = 'notif_pref_wallet_alerts';
}

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  late Box _settings;

  @override
  void initState() {
    super.initState();
    _settings = ref.read(localStorageServiceProvider).settings;
  }

  bool _get(String key) => _settings.get(key, defaultValue: true) as bool;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Notification settings'),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Ride updates'),
            subtitle: const Text('Driver arrival, trip status and OTP alerts'),
            value: _get(_NotificationPrefKeys.rideUpdates),
            onChanged: (v) => setState(() => _settings.put(_NotificationPrefKeys.rideUpdates, v)),
          ),
          SwitchListTile(
            title: const Text('Promotions & offers'),
            subtitle: const Text('New promo codes and discounts'),
            value: _get(_NotificationPrefKeys.promotions),
            onChanged: (v) => setState(() => _settings.put(_NotificationPrefKeys.promotions, v)),
          ),
          SwitchListTile(
            title: const Text('Wallet alerts'),
            subtitle: const Text('Top-ups, payments and refunds'),
            value: _get(_NotificationPrefKeys.walletAlerts),
            onChanged: (v) => setState(() => _settings.put(_NotificationPrefKeys.walletAlerts, v)),
          ),
        ],
      ),
    );
  }
}
