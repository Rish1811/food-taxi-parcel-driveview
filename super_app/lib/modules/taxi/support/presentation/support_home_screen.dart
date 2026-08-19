import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/core/utils/taxi_formatters.dart';
import 'package:superapp_user/design_system/components/ride/custom_app_bar.dart';
import 'package:superapp_user/design_system/components/ride/empty_state.dart';
import 'package:superapp_user/modules/taxi/support/application/support_providers.dart';

const _faqs = [
  {
    'q': 'How do I cancel a ride?',
    'a': 'Open your active ride and tap "Cancel ride" before the driver arrives. Cancellation charges may apply depending on timing.',
  },
  {
    'q': 'How is the fare calculated?',
    'a': 'Fare is based on distance, estimated duration, vehicle type and applicable surge pricing. You can see a full breakdown before confirming your ride.',
  },
  {
    'q': 'How do I add money to my wallet?',
    'a': 'Go to Profile > Wallet > Add money, choose an amount and complete payment via Razorpay.',
  },
  {
    'q': 'What if I left an item in the vehicle?',
    'a': 'Raise a support ticket with your ride details and our team will help connect you with the driver.',
  },
];

class SupportHomeScreen extends ConsumerWidget {
  const SupportHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(myTicketsProvider);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Help & support'),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myTicketsProvider),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: TaxiColors.primaryGradient),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Colors.white, size: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Safety center',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Emergency contacts, SOS & trip safety',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                    onPressed: () => context.push('/taxi/support/safety'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Frequently asked questions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...(_faqs.map((faq) => ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(faq['q']!, style: Theme.of(context).textTheme.titleMedium),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(faq['a']!, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                ))),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My tickets', style: Theme.of(context).textTheme.titleLarge),
                TextButton.icon(
                  onPressed: () => context.push('/taxi/support/tickets/new'),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Raise ticket'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ticketsAsync.when(
              data: (tickets) => tickets.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: EmptyState(
                        icon: Icons.confirmation_number_outlined,
                        title: 'No support tickets',
                        message: 'Raise a ticket if you need help with a ride, payment or anything else.',
                      ),
                    )
                  : Column(
                      children: tickets
                          .map((ticket) => Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  title: Text(ticket.title),
                                  subtitle: Text(
                                    '${ticket.ticketCode} · ${Formatters.date(ticket.updatedAt)}',
                                  ),
                                  trailing: Chip(
                                    label: Text(ticket.status),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onTap: () => context.push('/taxi/support/tickets/${ticket.ticketCode}'),
                                ),
                              ))
                          .toList(),
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Could not load your tickets'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
