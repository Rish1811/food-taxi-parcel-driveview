import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/core/utils/taxi_formatters.dart';
import 'package:superapp_user/design_system/components/feedback/taxi_snackbar_utils.dart';
import 'package:superapp_user/design_system/components/ride/custom_app_bar.dart';
import 'package:superapp_user/design_system/components/ride/primary_button.dart';
import 'package:superapp_user/modules/rental/application/rental_providers.dart';
import 'package:superapp_user/modules/rental/data/models/rental_vehicle_model.dart';

class RentalBookingScreen extends ConsumerStatefulWidget {
  final RentalVehicleModel vehicle;
  const RentalBookingScreen({super.key, required this.vehicle});

  @override
  ConsumerState<RentalBookingScreen> createState() => _RentalBookingScreenState();
}

class _RentalBookingScreenState extends ConsumerState<RentalBookingScreen> {
  RentalPricingModel? _selectedPackage;
  DateTime? _pickupDateTime;
  DateTime? _returnDateTime;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.vehicle.pricing.isNotEmpty) {
      _selectedPackage = widget.vehicle.pricing.first;
    }
  }

  Future<void> _pickDateTime({required bool isPickup}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
    if (time == null || !mounted) return;
    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isPickup) {
        _pickupDateTime = combined;
        if (_selectedPackage != null) {
          _returnDateTime = combined.add(Duration(hours: _selectedPackage!.durationHours));
        }
      } else {
        _returnDateTime = combined;
      }
    });
  }

  double get _payableNow {
    final pkg = _selectedPackage;
    if (pkg == null) return 0;
    return widget.vehicle.advancePayment.payableNowFor(pkg.price);
  }

  Future<void> _submit() async {
    final pkg = _selectedPackage;
    if (pkg == null) {
      SnackbarUtils.error(context, 'Please select a rental package');
      return;
    }
    if (_pickupDateTime == null || _returnDateTime == null) {
      SnackbarUtils.error(context, 'Please choose pickup and return time');
      return;
    }
    if (!_returnDateTime!.isAfter(_pickupDateTime!)) {
      SnackbarUtils.error(context, 'Return time must be after pickup time');
      return;
    }

    setState(() => _submitting = true);
    try {
      final bookingReference = 'RNT-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
      final payableNow = _payableNow;
      Map<String, dynamic>? payment;
      String paymentStatus = 'not_required';

      if (payableNow > 0) {
        final walletResult = await ref.read(rentalRepositoryProvider).payAdvanceWithWallet(
              amount: payableNow,
              bookingReference: bookingReference,
            );
        payment = walletResult;
        paymentStatus = 'paid';
      }

      await ref.read(rentalRepositoryProvider).createBooking(
            vehicleTypeId: widget.vehicle.id,
            bookingReference: bookingReference,
            packageId: pkg.id,
            packageLabel: pkg.label,
            durationHours: pkg.durationHours,
            price: pkg.price,
            extraHourPrice: pkg.extraHourPrice,
            pickupDateTime: _pickupDateTime!,
            returnDateTime: _returnDateTime!,
            paymentStatus: paymentStatus,
            payment: payment,
          );

      if (!mounted) return;
      SnackbarUtils.success(context, 'Rental booking request submitted');
      context.pop();
      context.push('/rental');
    } catch (e) {
      if (mounted) SnackbarUtils.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;

    return Scaffold(
      appBar: CustomAppBar(title: vehicle.name),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Choose a package', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...vehicle.pricing.map(
            (pkg) => RadioListTile<RentalPricingModel>(
              value: pkg,
              groupValue: _selectedPackage,
              contentPadding: EdgeInsets.zero,
              title: Text('${pkg.label} • ${Formatters.currency(pkg.price)}'),
              subtitle: Text('${pkg.includedKm} km included • ${Formatters.currency(pkg.extraHourPrice)}/extra hour'),
              onChanged: (v) => setState(() {
                _selectedPackage = v;
                if (_pickupDateTime != null && v != null) {
                  _returnDateTime = _pickupDateTime!.add(Duration(hours: v.durationHours));
                }
              }),
            ),
          ),
          const SizedBox(height: 20),
          Text('Pickup & return', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_rounded, color: TaxiColors.primary),
            title: const Text('Pickup time'),
            subtitle: Text(_pickupDateTime != null ? Formatters.dateTime(_pickupDateTime!) : 'Select pickup time'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _pickDateTime(isPickup: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_available_rounded, color: TaxiColors.primary),
            title: const Text('Return time'),
            subtitle: Text(_returnDateTime != null ? Formatters.dateTime(_returnDateTime!) : 'Select return time'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _pickDateTime(isPickup: false),
          ),
          if (_selectedPackage != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TaxiColors.lightBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total package cost'),
                      Text(Formatters.currency(_selectedPackage!.price)),
                    ],
                  ),
                  if (_payableNow > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(vehicle.advancePayment.label),
                        Text(
                          Formatters.currency(_payableNow),
                          style: const TextStyle(fontWeight: FontWeight.w600, color: TaxiColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Advance is deducted from your wallet balance now; the rest is settled at pickup.',
                      style: TextStyle(fontSize: 12, color: TaxiColors.lightTextSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: TaxiPrimaryButton(
            label: _payableNow > 0 ? 'Pay ${Formatters.currency(_payableNow)} & book' : 'Book rental',
            isLoading: _submitting,
            onPressed: _submit,
          ),
        ),
      ),
    );
  }
}
