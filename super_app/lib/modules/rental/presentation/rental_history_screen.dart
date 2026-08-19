import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/core/utils/taxi_formatters.dart';
import 'package:superapp_user/design_system/components/feedback/taxi_snackbar_utils.dart';
import 'package:superapp_user/design_system/components/ride/custom_app_bar.dart';
import 'package:superapp_user/design_system/components/ride/empty_state.dart';
import 'package:superapp_user/design_system/components/ride/primary_button.dart';
import 'package:superapp_user/modules/rental/application/rental_providers.dart';
import 'package:superapp_user/modules/rental/data/models/rental_booking_model.dart';

class RentalHistoryScreen extends ConsumerWidget {
  const RentalHistoryScreen({super.key});

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return TaxiColors.success;
      case 'cancelled':
      case 'rejected':
        return TaxiColors.error;
      case 'assigned':
      case 'confirmed':
        return TaxiColors.info;
      default:
        return TaxiColors.warning;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeRentalBookingProvider);
    final historyAsync = ref.watch(myRentalBookingsProvider);

    return Scaffold(
      appBar: const CustomAppBar(title: 'My rentals'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeRentalBookingProvider);
          ref.invalidate(myRentalBookingsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            activeAsync.when(
              data: (active) => active == null
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Active rental', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _ActiveRentalCard(booking: active),
                        const SizedBox(height: 24),
                      ],
                    ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            Text('History', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            historyAsync.when(
              data: (bookings) {
                if (bookings.isEmpty) {
                  return const EmptyState(
                    icon: Icons.car_rental_outlined,
                    title: 'No rental bookings yet',
                    message: 'Rentals you book will show up here.',
                  );
                }
                return Column(
                  children: bookings
                      .map(
                        (booking) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: TaxiColors.lightBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(booking.vehicleName, style: Theme.of(context).textTheme.titleSmall),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(booking.status).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      booking.status,
                                      style: TextStyle(color: _statusColor(booking.status), fontWeight: FontWeight.w600, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(booking.packageLabel, style: Theme.of(context).textTheme.bodySmall),
                              if (booking.pickupDateTime != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Pickup: ${Formatters.dateTime(booking.pickupDateTime!)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(Formatters.currency(booking.totalCost), style: Theme.of(context).textTheme.titleMedium),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Could not load rental history: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveRentalCard extends ConsumerStatefulWidget {
  final RentalBookingModel booking;
  const _ActiveRentalCard({required this.booking});

  @override
  ConsumerState<_ActiveRentalCard> createState() => _ActiveRentalCardState();
}

class _ActiveRentalCardState extends ConsumerState<_ActiveRentalCard> {
  bool _ending = false;

  Future<void> _endRide() async {
    setState(() => _ending = true);
    try {
      await ref.read(rentalRepositoryProvider).endActiveBooking(widget.booking.id);
      ref.invalidate(activeRentalBookingProvider);
      ref.invalidate(myRentalBookingsProvider);
      if (mounted) SnackbarUtils.success(context, 'Rental end requested');
    } catch (e) {
      if (mounted) SnackbarUtils.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: TaxiColors.primaryGradient),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(booking.vehicleName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 6),
          Text(booking.packageLabel, style: const TextStyle(color: Colors.white70)),
          if (booking.returnDateTime != null) ...[
            const SizedBox(height: 6),
            Text('Return by ${Formatters.dateTime(booking.returnDateTime!)}', style: const TextStyle(color: Colors.white70)),
          ],
          const SizedBox(height: 16),
          if (booking.status == 'assigned' || booking.status == 'confirmed')
            TaxiPrimaryButton(label: 'End rental', isLoading: _ending, useAccentGradient: true, onPressed: _endRide),
        ],
      ),
    );
  }
}
