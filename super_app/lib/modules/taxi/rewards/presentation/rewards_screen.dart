import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/modules/taxi/auth/application/auth_providers.dart';
import 'package:superapp_user/design_system/components/ride/custom_app_bar.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final code = user?.referralCode ?? '';

    return Scaffold(
      appBar: const CustomAppBar(title: 'Rewards'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: TaxiColors.accentGradient),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Invite friends, earn rewards',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: TaxiColors.primary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Share your code — you both get ride credit when they complete their first trip.',
                  style: TextStyle(color: TaxiColors.primary),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          code.isNotEmpty ? code : '—',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            letterSpacing: 2,
                            color: TaxiColors.primary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: TaxiColors.primary),
                        onPressed: code.isEmpty
                            ? null
                            : () {
                                Clipboard.setData(ClipboardData(text: code));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Referral code copied')),
                                );
                              },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_rounded, color: TaxiColors.primary),
                        onPressed: code.isEmpty
                            ? null
                            : () => Share.share(
                                  'Book rides with this app! Use my referral code $code to get ride credit on your first trip.',
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.group_rounded,
                  label: 'Friends referred',
                  value: '${user?.referralCount ?? 0}',
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: _StatCard(
                  icon: Icons.stars_rounded,
                  label: 'Loyalty points',
                  value: 'Coming soon',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('How it works', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const _StepTile(number: '1', text: 'Share your referral code with friends'),
          const _StepTile(number: '2', text: 'They sign up and enter your code'),
          const _StepTile(number: '3', text: 'You both get ride credit after their first completed ride'),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TaxiColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: TaxiColors.primary),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String number;
  final String text;
  const _StepTile({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: TaxiColors.primary.withValues(alpha: 0.1),
            child: Text(number, style: const TextStyle(color: TaxiColors.primary, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
