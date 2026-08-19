import 'package:superapp_user/core/storage/storage_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/design_system/components/ride/custom_app_bar.dart';

const _appLockKey = 'security_app_lock_enabled';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  bool _appLock = false;

  @override
  void initState() {
    super.initState();
    _appLock = ref.read(localStorageServiceProvider).settings.get(_appLockKey, defaultValue: false) as bool;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Security'),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('App lock'),
            subtitle: const Text('Ask for confirmation before opening the app'),
            value: _appLock,
            onChanged: (v) {
              setState(() => _appLock = v);
              ref.read(localStorageServiceProvider).settings.put(_appLockKey, v);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Emergency contacts'),
            subtitle: const Text('Manage who is alerted during SOS'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/taxi/emergency-contacts'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.phonelink_lock_outlined),
            title: const Text('Active session'),
            subtitle: const Text('You are signed in on this device via phone number verification'),
          ),
        ],
      ),
    );
  }
}
