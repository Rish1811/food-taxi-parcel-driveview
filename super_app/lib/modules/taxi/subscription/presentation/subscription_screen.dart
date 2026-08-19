import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/core/utils/taxi_formatters.dart';
import 'package:superapp_user/design_system/components/feedback/taxi_snackbar_utils.dart';
import 'package:superapp_user/design_system/components/ride/custom_app_bar.dart';
import 'package:superapp_user/design_system/components/ride/primary_button.dart';
import 'package:superapp_user/modules/taxi/subscription/application/subscription_providers.dart';
import 'package:superapp_user/modules/taxi/subscription/data/models/subscription_plan_model.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(mySubscriptionSummaryProvider);
    final plansAsync = ref.watch(subscriptionPlansProvider);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Ride subscriptions'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mySubscriptionSummaryProvider);
          ref.invalidate(subscriptionPlansProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            summaryAsync.when(
              data: (summary) {
                if (summary.activePlans.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your active plans', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ...summary.activePlans.map((plan) => _ActivePlanCard(plan: plan)),
                    const SizedBox(height: 24),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Could not load your subscriptions: $e'),
            ),
            Text('Available plans', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            plansAsync.when(
              data: (plans) {
                if (plans.isEmpty) {
                  return const Text('No subscription plans available right now');
                }
                return Column(
                  children: plans.map((plan) => _PlanCard(plan: plan)).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Could not load plans: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivePlanCard extends StatelessWidget {
  final UserSubscriptionModel plan;
  const _ActivePlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: TaxiColors.primaryGradient),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            plan.isUnlimited ? 'Unlimited rides' : '${plan.ridesRemaining ?? 0} of ${plan.rideLimit} rides remaining',
            style: const TextStyle(color: Colors.white70),
          ),
          if (plan.expiresAt != null) ...[
            const SizedBox(height: 6),
            Text('Valid until ${Formatters.date(plan.expiresAt!)}', style: const TextStyle(color: Colors.white70)),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends ConsumerStatefulWidget {
  final SubscriptionPlanModel plan;
  const _PlanCard({required this.plan});

  @override
  ConsumerState<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<_PlanCard> {
  bool _purchasing = false;

  Future<void> _purchase() async {
    setState(() => _purchasing = true);
    try {
      await ref.read(subscriptionRepositoryProvider).purchase(widget.plan.id);
      ref.invalidate(mySubscriptionSummaryProvider);
      if (mounted) SnackbarUtils.success(context, 'Subscription purchased successfully');
    } catch (e) {
      if (mounted) SnackbarUtils.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TaxiColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(plan.name, style: Theme.of(context).textTheme.titleMedium)),
              Text(Formatters.currency(plan.amount), style: const TextStyle(color: TaxiColors.primary, fontWeight: FontWeight.w600)),
            ],
          ),
          if (plan.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(plan.description, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          Text(
            plan.isUnlimited ? 'Unlimited rides • ${plan.durationDays} days' : '${plan.rideLimit} rides • ${plan.durationDays} days',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: TaxiColors.primary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),
          TaxiPrimaryButton(label: 'Buy with wallet', isLoading: _purchasing, onPressed: _purchase),
        ],
      ),
    );
  }
}
