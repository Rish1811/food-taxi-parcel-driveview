import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/design_system/components/feedback/taxi_snackbar_utils.dart';
import 'package:superapp_user/design_system/components/ride/app_text_field.dart';
import 'package:superapp_user/design_system/components/ride/custom_app_bar.dart';
import 'package:superapp_user/design_system/components/ride/custom_bottom_sheet.dart';
import 'package:superapp_user/design_system/components/ride/primary_button.dart';
import 'package:superapp_user/design_system/components/ride/section_title.dart';
import 'package:superapp_user/modules/taxi/home/application/fare_calculator.dart';
import 'package:superapp_user/modules/taxi/home/application/home_providers.dart';
import 'package:superapp_user/modules/taxi/home/data/models/vehicle_type_model.dart';
import 'package:superapp_user/modules/parcel/application/delivery_providers.dart';
import 'package:superapp_user/modules/parcel/data/models/parcel_model.dart';

class _Place {
  final String address;
  final double lat;
  final double lng;
  const _Place({required this.address, required this.lat, required this.lng});
}

class NewDeliveryScreen extends ConsumerStatefulWidget {
  const NewDeliveryScreen({super.key});

  @override
  ConsumerState<NewDeliveryScreen> createState() => _NewDeliveryScreenState();
}

class _NewDeliveryScreenState extends ConsumerState<NewDeliveryScreen> {
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _senderNameController = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _receiverNameController = TextEditingController();
  final _receiverPhoneController = TextEditingController();
  final _weightController = TextEditingController();
  final _descriptionController = TextEditingController();

  _Place? _pickup;
  _Place? _drop;
  String _category = parcelCategories.first;
  VehicleTypeModel? _selectedVehicle;
  String _paymentMethod = 'cash';
  bool _submitting = false;
  bool _resolvingPickup = false;
  bool _resolvingDrop = false;

  @override
  void initState() {
    super.initState();
    _prefillPickup();
  }

  Future<void> _prefillPickup() async {
    final address = await ref.read(currentAddressProvider.future);
    final position = await ref.read(currentPositionProvider.future);
    if (!mounted) return;
    final lat = position?.latitude ?? 22.7196;
    final lng = position?.longitude ?? 75.8577;
    final resolved = address.isNotEmpty ? address : 'Current location';
    setState(() {
      _pickup = _Place(address: resolved, lat: lat, lng: lng);
      _pickupController.text = resolved;
    });
  }

  Future<void> _resolve({required bool isDrop}) async {
    final text = (isDrop ? _dropController : _pickupController).text.trim();
    if (text.length < 3) return;
    setState(() => isDrop ? _resolvingDrop = true : _resolvingPickup = true);
    try {
      final locations = await locationFromAddress(text);
      if (locations.isNotEmpty && mounted) {
        final place = _Place(address: text, lat: locations.first.latitude, lng: locations.first.longitude);
        setState(() {
          if (isDrop) {
            _drop = place;
          } else {
            _pickup = place;
          }
        });
      } else if (mounted) {
        SnackbarUtils.error(context, 'Could not find that address');
      }
    } catch (_) {
      if (mounted) SnackbarUtils.error(context, 'Could not find that address');
    } finally {
      if (mounted) setState(() => isDrop ? _resolvingDrop = false : _resolvingPickup = false);
    }
  }

  double? _estimatedFare(WidgetRef ref, VehicleTypeModel vehicle) {
    final pickup = _pickup;
    final drop = _drop;
    if (pickup == null || drop == null) return null;
    final setPrices = ref.watch(setPricesProvider).value ?? [];
    if (setPrices.isEmpty) return null;
    final pricing = setPrices.firstWhere(
      (p) => p.vehicleTypeId == vehicle.id,
      orElse: () => setPrices.first,
    );
    final distanceMeters = ref.read(taxiLocationServiceProvider).distanceMeters(
          pickup.lat,
          pickup.lng,
          drop.lat,
          drop.lng,
        );
    final durationSeconds = (distanceMeters / 1000) / 25 * 3600;
    final breakdown = FareCalculator.estimate(
      pricing: pricing,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
    return breakdown.total;
  }

  Future<void> _submit() async {
    if (_pickup == null || _drop == null) {
      SnackbarUtils.error(context, 'Please set both pickup and drop addresses');
      return;
    }
    if (_selectedVehicle == null) {
      SnackbarUtils.error(context, 'Please select a vehicle');
      return;
    }
    if (_receiverNameController.text.trim().isEmpty || _receiverPhoneController.text.trim().isEmpty) {
      SnackbarUtils.error(context, 'Please add receiver details');
      return;
    }

    final fare = _estimatedFare(ref, _selectedVehicle!) ?? 0;
    setState(() => _submitting = true);
    try {
      final parcel = ParcelModel(
        category: _category,
        weight: _weightController.text.trim(),
        description: _descriptionController.text.trim(),
        senderName: _senderNameController.text.trim(),
        senderMobile: _senderPhoneController.text.trim(),
        receiverName: _receiverNameController.text.trim(),
        receiverMobile: _receiverPhoneController.text.trim(),
      );
      final delivery = await ref.read(deliveryRepositoryProvider).createDelivery(
            pickup: [_pickup!.lng, _pickup!.lat],
            drop: [_drop!.lng, _drop!.lat],
            pickupAddress: _pickup!.address,
            dropAddress: _drop!.address,
            fare: fare,
            vehicleTypeId: _selectedVehicle!.id,
            parcel: parcel,
            paymentMethod: _paymentMethod,
          );
      if (!mounted) return;
      context.pushReplacement('/taxi/rides/${delivery.ride.rideId}/track');
    } catch (e) {
      if (mounted) SnackbarUtils.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _senderNameController.dispose();
    _senderPhoneController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _weightController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showPaymentSheet() {
    CustomBottomSheet.show(
      context,
      title: 'Payment method',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<String>(
            value: 'cash',
            groupValue: _paymentMethod,
            title: const Text('Cash'),
            secondary: const Icon(Icons.money_rounded),
            onChanged: (v) {
              setState(() => _paymentMethod = v!);
              Navigator.of(context).pop();
            },
          ),
          RadioListTile<String>(
            value: 'wallet',
            groupValue: _paymentMethod,
            title: const Text('Wallet'),
            secondary: const Icon(Icons.account_balance_wallet_outlined),
            onChanged: (v) {
              setState(() => _paymentMethod = v!);
              Navigator.of(context).pop();
            },
          ),
          RadioListTile<String>(
            value: 'razorpay',
            groupValue: _paymentMethod,
            title: const Text('Card / UPI'),
            secondary: const Icon(Icons.credit_card_rounded),
            onChanged: (v) {
              setState(() => _paymentMethod = v!);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicleTypesAsync = ref.watch(vehicleTypesProvider);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Send a package'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionTitle(title: 'Pickup & drop'),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.circle, size: 12, color: TaxiColors.success),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: _pickupController,
                  hint: 'Pickup address',
                  suffix: _resolvingPickup
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => _resolve(isDrop: false), child: const Text('Locate pickup')),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: TaxiColors.error),
              const SizedBox(width: 10),
              Expanded(
                child: AppTextField(
                  controller: _dropController,
                  hint: 'Drop address',
                  suffix: _resolvingDrop
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => _resolve(isDrop: true), child: const Text('Locate drop')),
          ),
          const SizedBox(height: 20),
          const SectionTitle(title: 'Sender details'),
          const SizedBox(height: 12),
          AppTextField(controller: _senderNameController, hint: 'Sender name'),
          const SizedBox(height: 12),
          AppTextField(
            controller: _senderPhoneController,
            hint: 'Sender phone',
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 20),
          const SectionTitle(title: 'Receiver details'),
          const SizedBox(height: 12),
          AppTextField(controller: _receiverNameController, hint: 'Receiver name'),
          const SizedBox(height: 12),
          AppTextField(
            controller: _receiverPhoneController,
            hint: 'Receiver phone',
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 20),
          const SectionTitle(title: 'Parcel details'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: parcelCategories
                .map(
                  (c) => ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _weightController,
            hint: 'Approx. weight (kg)',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          AppTextField(controller: _descriptionController, hint: 'Item description', maxLines: 3),
          const SizedBox(height: 20),
          const SectionTitle(title: 'Choose a vehicle'),
          const SizedBox(height: 12),
          vehicleTypesAsync.when(
            data: (vehicles) {
              if (vehicles.isEmpty) {
                return const Text('No vehicles available right now');
              }
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: vehicles.map((v) {
                  final fare = _estimatedFare(ref, v);
                  final selected = _selectedVehicle?.id == v.id;
                  return ChoiceChip(
                    label: Text(fare != null ? '${v.name} • ₹${fare.toStringAsFixed(0)}' : v.name),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedVehicle = v),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Could not load vehicles: $e'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.payments_outlined, color: TaxiColors.primary),
            title: const Text('Payment method'),
            subtitle: Text(_paymentMethod == 'cash' ? 'Cash' : _paymentMethod.toUpperCase()),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _showPaymentSheet,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: TaxiPrimaryButton(
            label: 'Book delivery',
            isLoading: _submitting,
            onPressed: _submit,
          ),
        ),
      ),
    );
  }
}
