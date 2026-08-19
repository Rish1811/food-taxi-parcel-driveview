import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/modules/taxi/profile/application/emergency_contacts_provider.dart';
import 'package:superapp_user/design_system/components/ride/profile_tile.dart';

class SafetyCenterScreen extends ConsumerWidget {
  const SafetyCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(emergencyContactsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Safety center')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GestureDetector(
            onTap: () => context.push('/taxi/sos'),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: TaxiColors.error,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emergency_share_rounded, color: Colors.white, size: 36),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Emergency SOS',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17)),
                        SizedBox(height: 4),
                        Text('Alert our safety team instantly', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Trusted contacts', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (contacts.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_add_alt_rounded),
                title: const Text('Add an emergency contact'),
                subtitle: const Text('They can be reached quickly during a ride'),
                onTap: () => context.push('/taxi/emergency-contacts'),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final contact in contacts)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: TaxiColors.primary.withValues(alpha: 0.08),
                        child: Text(
                          contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: TaxiColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      title: Text(contact.name),
                      subtitle: Text(contact.phone),
                      trailing: IconButton(
                        icon: const Icon(Icons.call_rounded, color: TaxiColors.success),
                        onPressed: () => launchUrl(Uri.parse('tel:${contact.phone}')),
                      ),
                    ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Manage contacts'),
                    onTap: () => context.push('/taxi/emergency-contacts'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Text('More', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ProfileTile(
                  icon: Icons.ios_share_rounded,
                  title: 'Share my trip',
                  subtitle: 'Let someone track your ride',
                  onTap: () => Share.share(
                    'I\'m on a ride booked through the Taxi app. I\'ll share updates here.',
                  ),
                ),
                const Divider(height: 1),
                ProfileTile(
                  icon: Icons.local_police_outlined,
                  title: 'Call local police',
                  onTap: () => launchUrl(Uri.parse('tel:100')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
