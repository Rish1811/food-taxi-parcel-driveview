import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/core/utils/taxi_formatters.dart';
import 'package:superapp_user/design_system/components/ride/custom_app_bar.dart';
import 'package:superapp_user/design_system/components/ride/custom_bottom_sheet.dart';
import 'package:superapp_user/design_system/components/ride/price_card.dart';
import 'package:superapp_user/design_system/components/ride/primary_button.dart';
import 'package:superapp_user/modules/taxi/home/application/booking_controller.dart';
import 'package:superapp_user/modules/taxi/home/application/booking_state.dart';
import 'package:superapp_user/modules/taxi/home/presentation/schedule_ride_sheet.dart';

class ConfirmBookingScreen extends ConsumerWidget {
  const ConfirmBookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingControllerProvider);
    final controller = ref.read(bookingControllerProvider.notifier);
    final fare = booking.fareBreakdown;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Confirm your ride'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _RouteSummary(booking: booking),
          const SizedBox(height: 20),
          if (fare != null)
            PriceCard(
              label: 'Estimated fare',
              amount: fare.total,
              breakdown: [
                MapEntry('Base fare', fare.baseFare),
                MapEntry('Distance', fare.distanceFare),
                MapEntry('Time', fare.timeFare),
                MapEntry('Taxes & fees', fare.serviceTax),
              ],
            ),
          const SizedBox(height: 16),
          if (booking.canUseSafeRide) ...[
            _SafeRideCard(
              option: booking.safeRideOption!,
              enabled: booking.safeRide,
              onChanged: controller.setSafeRide,
            ),
            const SizedBox(height: 8),
          ],
          _OptionRow(
            icon: Icons.payments_outlined,
            label: 'Payment method',
            value: booking.paymentMethod == 'cash' ? 'Cash' : booking.paymentMethod.toUpperCase(),
            onTap: () => _showPaymentSheet(context, controller, booking.paymentMethod),
          ),
          _OptionRow(
            icon: Icons.local_offer_outlined,
            label: 'Promo code',
            value: booking.promoCode ?? 'Add promo code',
            onTap: () => context.push('/taxi/promo'),
          ),
          _OptionRow(
            icon: Icons.schedule_rounded,
            label: 'Ride time',
            value: booking.scheduledAt != null
                ? '${booking.scheduledAt!.day}/${booking.scheduledAt!.month} ${TimeOfDay.fromDateTime(booking.scheduledAt!).format(context)}'
                : 'Ride now',
            onTap: () async {
              final selected = await CustomBottomSheet.show<DateTime?>(
                context,
                child: ScheduleRideSheet(initial: booking.scheduledAt),
              );
              controller.setScheduledAt(selected);
            },
          ),
          if (booking.error != null) ...[
            const SizedBox(height: 12),
            Text(booking.error!, style: const TextStyle(color: TaxiColors.error)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: TaxiPrimaryButton(
            label: 'Confirm booking',
            isLoading: booking.isSubmitting,
            onPressed: fare == null
                ? null
                : () async {
                    final success = await controller.confirmBooking();
                    if (!context.mounted) return;
                    if (success) {
                      context.pushReplacement('/taxi/searching');
                    } else {
                      context.pushReplacement('/taxi/no-driver');
                    }
                  },
          ),
        ),
      ),
    );
  }

  void _showPaymentSheet(BuildContext context, BookingController controller, String current) {
    CustomBottomSheet.show(
      context,
      title: 'Payment method',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<String>(
            value: 'cash',
            groupValue: current,
            title: const Text('Cash'),
            secondary: const Icon(Icons.money_rounded),
            onChanged: (v) {
              controller.setPaymentMethod(v!);
              Navigator.of(context).pop();
            },
          ),
          RadioListTile<String>(
            value: 'wallet',
            groupValue: current,
            title: const Text('Wallet'),
            secondary: const Icon(Icons.account_balance_wallet_outlined),
            onChanged: (v) {
              controller.setPaymentMethod(v!);
              Navigator.of(context).pop();
            },
          ),
          RadioListTile<String>(
            value: 'razorpay',
            groupValue: current,
            title: const Text('Card / UPI'),
            secondary: const Icon(Icons.credit_card_rounded),
            onChanged: (v) {
              controller.setPaymentMethod(v!);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  final BookingState booking;
  const _RouteSummary({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TaxiColors.lightBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 10, color: TaxiColors.success),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  booking.pickup?.address ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [SizedBox(width: 6), _DottedLine()],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: TaxiColors.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  booking.drop?.address ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Formatters.distanceKm(booking.distanceMeters ?? 0),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                Formatters.durationMinutes(booking.durationSeconds ?? 0),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DottedLine extends StatelessWidget {
  const _DottedLine();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 14,
      width: 1,
      child: ColoredBox(color: TaxiColors.lightBorder),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _OptionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: TaxiColors.primary),
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}


/// Safe Ride opt-in.
///
/// Shown only when the admin has enabled it for the selected vehicle. The extra cost is
/// stated up front - the rider should never discover the surcharge only on the receipt.
class _SafeRideCard extends StatelessWidget {
  final SafeRideOption option;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _SafeRideCard({
    required this.option,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: enabled ? TaxiColors.primary.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled ? TaxiColors.primary : Colors.black12,
          width: enabled ? 1.4 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: enabled
                  ? TaxiColors.primary.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.health_and_safety_outlined,
              size: 20,
              color: enabled ? TaxiColors.primary : Colors.black54,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Safe Ride',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  option.note.isNotEmpty
                      ? option.note
                      : 'Had a drink? Get home safely on our care tariff.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.black54,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '+ ' + TaxiFormatters.currency(option.surcharge),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: TaxiColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Total ' + TaxiFormatters.currency(option.safeRideFare),
                      style: const TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Switch.adaptive(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}
