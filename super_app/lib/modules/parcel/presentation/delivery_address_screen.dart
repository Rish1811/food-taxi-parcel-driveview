import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/modules/taxi/taxi_constants.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/design_system/components/feedback/taxi_snackbar_utils.dart';
import 'package:superapp_user/modules/taxi/auth/application/auth_providers.dart';
import 'package:superapp_user/modules/taxi/home/application/booking_state.dart';
import 'package:superapp_user/modules/taxi/home/application/home_providers.dart';
import 'package:superapp_user/modules/taxi/home/application/recent_searches_provider.dart';
import 'package:superapp_user/modules/parcel/application/delivery_booking_controller.dart';
import 'package:superapp_user/modules/parcel/presentation/delivery_contacts_sheet.dart';

class _Suggestion {
  final String title;
  final String address;
  final String placeId;
  const _Suggestion({required this.title, required this.address, required this.placeId});
}

/// Step 2: Details & Address Screen matching user's exact reference UI.
class DeliveryAddressScreen extends ConsumerStatefulWidget {
  const DeliveryAddressScreen({super.key});

  @override
  ConsumerState<DeliveryAddressScreen> createState() => _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends ConsumerState<DeliveryAddressScreen> {
  final _dropController = TextEditingController();
  Timer? _debounce;
  List<_Suggestion> _results = [];
  bool _searching = false;
  bool _booking = false;
  String _sessionToken = '';

  @override
  void initState() {
    super.initState();
    final state = ref.read(deliveryBookingProvider);
    if (state.drop != null) _dropController.text = state.drop!.address;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authControllerProvider).user;
      ref.read(deliveryBookingProvider.notifier).prefillSenderFrom(
            name: user?.name,
            phone: user?.phone,
          );
      _ensureVehicleSelected();
    });
  }

  /// Pricing is per vehicle type, so reaching this screen without one leaves
  /// the fare card permanently unavailable. Falls back to the first vehicle in
  /// the chosen category (then any delivery vehicle) so the rider still gets a
  /// price instead of a dead end.
  Future<void> _ensureVehicleSelected() async {
    if (ref.read(deliveryBookingProvider).vehicleTypeId.isNotEmpty) return;

    try {
      final categoryId = ref.read(deliveryBookingProvider).deliveryCategoryId;
      var candidates = categoryId.isEmpty
          ? const []
          : await ref.read(deliveryVehiclesByCategoryProvider(categoryId).future);

      if (candidates.isEmpty) {
        candidates = await ref.read(deliveryVehicleTypesProvider.future);
      }
      if (candidates.isEmpty || !mounted) return;

      final vehicle = candidates.first;
      ref.read(deliveryBookingProvider.notifier).selectVehicle(
            id: vehicle.id,
            name: vehicle.name,
          );
    } catch (_) {
      // Leaves the fare card's own error visible rather than masking it.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _dropController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    if (_sessionToken.isEmpty) {
      _sessionToken = DateTime.now().microsecondsSinceEpoch.toString();
    }

    try {
      final response = await Dio().get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {
          'input': query,
          'key': TaxiConstants.mapKey,
          'sessiontoken': _sessionToken,
          'components': 'country:in',
        },
      );

      if (response.data?['status'] == 'OK') {
        final predictions = response.data['predictions'] as List;
        if (!mounted) return;
        setState(() {
          _results = predictions
              .map((p) => _Suggestion(
                    title: (p['structured_formatting']?['main_text'] ??
                            (p['description'] ?? '').toString().split(',').first)
                        .toString(),
                    address: (p['description'] ?? '').toString(),
                    placeId: (p['place_id'] ?? '').toString(),
                  ))
              .toList();
          _searching = false;
        });
        return;
      }
    } catch (_) {
      // Falls through to the empty state below.
    }

    if (mounted) setState(() { _results = []; _searching = false; });
  }

  Future<void> _selectSuggestion(_Suggestion suggestion) async {
    FocusScope.of(context).unfocus();
    try {
      final response = await Dio().get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': suggestion.placeId,
          'key': TaxiConstants.mapKey,
          'sessiontoken': _sessionToken,
          'fields': 'formatted_address,geometry',
        },
      );
      _sessionToken = '';

      if (response.data?['status'] != 'OK') {
        if (mounted) SnackbarUtils.error(context, 'Could not locate that place');
        return;
      }

      final location = response.data['result']['geometry']['location'];
      final lat = (location['lat'] as num).toDouble();
      final lng = (location['lng'] as num).toDouble();

      ref.read(recentSearchesProvider.notifier)
          .add(address: suggestion.address, lat: lat, lng: lng);
      ref.read(deliveryBookingProvider.notifier).setDrop(
            BookingLocation(lat: lat, lng: lng, address: suggestion.address),
          );

      if (!mounted) return;
      setState(() {
        _dropController.text = suggestion.address;
        _results = [];
      });
    } catch (_) {
      if (mounted) SnackbarUtils.error(context, 'Could not locate that place');
    }
  }

  /// Resolves a suggestion chip to real coordinates.
  ///
  /// Every chip used to share one hardcoded point (the Indore centroid), so
  /// "Palasia Square" and "Vijay Nagar" booked the parcel to the same place.
  /// Now the name goes through the same Places lookup as a typed search.
  Future<void> _selectQuickLocation(String locationName) async {
    FocusScope.of(context).unfocus();
    final query = locationName.contains(',')
        ? locationName
        : '$locationName, Indore, Madhya Pradesh';

    _dropController.text = query;
    setState(() { _results = []; _searching = true; });

    if (_sessionToken.isEmpty) {
      _sessionToken = DateTime.now().microsecondsSinceEpoch.toString();
    }

    try {
      final response = await Dio().get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {
          'input': query,
          'key': TaxiConstants.mapKey,
          'sessiontoken': _sessionToken,
          'components': 'country:in',
        },
      );

      final predictions = response.data?['status'] == 'OK'
          ? (response.data['predictions'] as List)
          : const [];

      if (predictions.isEmpty) {
        if (mounted) {
          setState(() => _searching = false);
          SnackbarUtils.error(context, 'Could not locate $locationName');
        }
        return;
      }

      final first = predictions.first;
      if (mounted) setState(() => _searching = false);

      // Reuses the details lookup so the drop is stored with real geometry.
      await _selectSuggestion(_Suggestion(
        title: locationName,
        address: (first['description'] ?? query).toString(),
        placeId: (first['place_id'] ?? '').toString(),
      ));
    } catch (_) {
      if (mounted) {
        setState(() => _searching = false);
        SnackbarUtils.error(context, 'Could not locate $locationName');
      }
    }
  }

  /// Waits for the server fare, retrying once if it has not been requested yet.
  ///
  /// Returns null if it never arrives, so the caller can fail loudly rather
  /// than booking a delivery with no agreed price.
  Future<dynamic> _awaitQuote() async {
    final notifier = ref.read(deliveryBookingProvider.notifier);

    for (var attempt = 0; attempt < 20; attempt++) {
      final state = ref.read(deliveryBookingProvider);
      if (state.quote != null) return state.quote;

      // Nothing in flight and nothing cached — kick one off.
      if (!state.quoting && attempt == 0) {
        unawaited(notifier.retryQuote());
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    return ref.read(deliveryBookingProvider).quote;
  }

  Future<void> _confirm() async {
    final state = ref.read(deliveryBookingProvider);

    if (state.drop == null) {
      SnackbarUtils.info(context, 'Choose where the parcel is going');
      return;
    }
    if (!state.hasSender || !state.hasReceiver) {
      final saved = await DeliveryContactsSheet.show(context);
      if (!saved) return;
    }
    if (!mounted) return;

    setState(() => _booking = true);

    // The quote is fetched in the background when the drop is chosen, so by the
    // time contacts are entered it is usually ready. Bailing out here used to
    // make the rider tap Confirm a second time for no visible reason, so wait
    // for it instead.
    final quote = await _awaitQuote();
    if (!mounted) return;
    if (quote == null) {
      SnackbarUtils.error(context, 'Could not price this delivery. Please try again.');
      setState(() => _booking = false);
      return;
    }

    try {
      final rideId = await ref.read(deliveryBookingProvider.notifier).confirm();
      if (!mounted) return;
      context.pushReplacement('/parcel/searching/$rideId');
    } catch (e) {
      if (mounted) {
        SnackbarUtils.error(context, e.toString());
        setState(() => _booking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deliveryBookingProvider);
    final recents = ref.watch(recentSearchesProvider);
    final addressAsync = ref.watch(currentAddressProvider);
    final currentAddr = addressAsync.value ?? 'Fetching location...';
    final pickupAddressToDisplay = (state.pickup?.address != null && state.pickup!.address.isNotEmpty)
        ? state.pickup!.address
        : currentAddr;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 1,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.vehicleName.isEmpty ? 'PARCEL DELIVERY' : state.vehicleName.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2563EB),
              ),
            ),
            const Text(
              'Details & Address',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // Top Pickup & Deliver To Route Box
                  _RouteCard(
                    pickup: pickupAddressToDisplay,
                    dropController: _dropController,
                    onDropChanged: _onQueryChanged,
                    onClearDrop: () {
                      setState(() {
                        _dropController.clear();
                        _results = [];
                      });
                      ref.read(deliveryBookingProvider.notifier).clearDrop();
                    },
                  ),

                  const SizedBox(height: 12),

                  // Pin on Map & Contact Details Action Row
                  _ActionRow(
                    onPinMap: () {
                      // Action to select on map
                      SnackbarUtils.info(context, 'Tap drop location on map');
                    },
                    onContacts: () async {
                      await DeliveryContactsSheet.show(context);
                      if (mounted) setState(() {});
                    },
                  ),

                  // Appears the moment a drop is chosen, directly under the
                  // route — the price is the deciding factor, so it should not
                  // sit below a long list of suggestions.
                  if (state.drop != null) ...[
                    const SizedBox(height: 14),
                    _FareCard(
                      quoting: state.quoting,
                      error: state.error,
                      quote: state.quote,
                      onRetry: () => ref.read(deliveryBookingProvider.notifier).retryQuote(),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Sender Info Card
                  _SenderInfoCard(
                    senderName: state.senderName.isEmpty ? 'Om' : state.senderName,
                    senderMobile: state.senderMobile.isEmpty ? '7223077890' : state.senderMobile,
                    onEdit: () async {
                      await DeliveryContactsSheet.show(context);
                      if (mounted) setState(() {});
                    },
                  ),

                  const SizedBox(height: 20),

                  // Search Results if typing
                  if (_searching)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_results.isNotEmpty) ...[
                    const _GroupHeader(title: 'SEARCH RESULTS'),
                    ..._results.map((r) => _SuggestionTile(
                          title: r.title,
                          subtitle: r.address,
                          onTap: () => _selectSuggestion(r),
                        )),
                  ] else ...[
                    // Suggestions Section matching reference image UI
                    const _GroupHeader(title: 'SUGGESTIONS'),
                    const SizedBox(height: 8),

                    // Near Current Pickup
                    const _SubHeader(title: 'NEAR CURRENT PICKUP'),
                    const SizedBox(height: 8),
                    _LocationGrid(
                      items: const [
                        _LocationItem(name: 'Palasia Square', isNear: true),
                        _LocationItem(name: 'LIG Colony', isNear: true),
                        _LocationItem(name: 'Geeta Bhawan', isNear: true),
                        _LocationItem(name: 'MG Road', isNear: true),
                      ],
                      onSelect: _selectQuickLocation,
                    ),

                    const SizedBox(height: 16),

                    // Popular Locations
                    const _SubHeader(title: 'POPULAR LOCATIONS'),
                    const SizedBox(height: 8),
                    _LocationGrid(
                      items: const [
                        _LocationItem(name: 'Pipaliyahana, Indore', isNear: false),
                        _LocationItem(name: 'Vijay Nagar', isNear: false),
                        _LocationItem(name: 'Vijay Nagar Square', isNear: false),
                        _LocationItem(name: 'Rajwada', isNear: false),
                        _LocationItem(name: 'Bhawarkua', isNear: false),
                        _LocationItem(name: 'MG Road', isNear: false),
                      ],
                      onSelect: _selectQuickLocation,
                    ),

                    // Recents list if available
                    if (recents.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _SubHeader(title: 'RECENT SEARCHES'),
                      const SizedBox(height: 6),
                      ...recents.map((place) => _SuggestionTile(
                            title: place.address.split(',').first,
                            subtitle: place.address,
                            onTap: () {
                              ref.read(deliveryBookingProvider.notifier).setDrop(
                                    BookingLocation(
                                      lat: place.lat,
                                      lng: place.lng,
                                      address: place.address,
                                    ),
                                  );
                              setState(() => _dropController.text = place.address);
                            },
                          )),
                    ],
                  ],

                  const SizedBox(height: 80), // Padding for sticky bottom button
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        color: const Color(0xFFF6F8FC),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            onPressed: (state.drop != null && !_booking) || state.drop == null ? () {
              if (state.drop == null) {
                SnackbarUtils.info(context, 'Please select or search drop location');
              } else {
                _confirm();
              }
            } : null,
            child: _booking
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        state.drop == null ? 'Select Drop Location' : 'Confirm Receiver Details',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Route Box Card containing Pickup Address & Drop Search Box
class _RouteCard extends StatelessWidget {
  final String pickup;
  final TextEditingController dropController;
  final ValueChanged<String> onDropChanged;
  final VoidCallback onClearDrop;

  const _RouteCard({
    required this.pickup,
    required this.dropController,
    required this.onDropChanged,
    required this.onClearDrop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pickup Row
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF10B981), width: 3),
                ),
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PICK UP FROM',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pickup,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Connecting Vertical Line
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 2,
                height: 18,
                color: const Color(0xFFCBD5E1),
              ),
            ),
          ),

          // Deliver To Row
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFF5C2B), width: 3),
                ),
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5C2B),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2563EB), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DELIVER TO',
                              style: TextStyle(
                                fontSize: 9.5,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            TextField(
                              controller: dropController,
                              onChanged: onDropChanged,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.only(top: 2, bottom: 2),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                hintText: 'Search drop location...',
                                hintStyle: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (dropController.text.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: onClearDrop,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF64748B),
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Action Row with "Pin on map" and "Contact Details" buttons
class _ActionRow extends StatelessWidget {
  final VoidCallback onPinMap;
  final VoidCallback onContacts;

  const _ActionRow({
    required this.onPinMap,
    required this.onContacts,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Pin on Map Button
        Expanded(
          child: InkWell(
            onTap: onPinMap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on_outlined, color: Color(0xFF2563EB), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Pin on map',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Contact Details Button
        Expanded(
          child: InkWell(
            onTap: onContacts,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline_rounded, color: Color(0xFF2563EB), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Contact Details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sender Info Box with left blue accent line & EDIT pill button
class _SenderInfoCard extends StatelessWidget {
  final String senderName;
  final String senderMobile;
  final VoidCallback onEdit;

  const _SenderInfoCard({
    required this.senderName,
    required this.senderMobile,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: const Border(
          left: BorderSide(color: Color(0xFF2563EB), width: 4),
        ),
      ),
      child: Row(
        children: [
          // Green dot indicator
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),

          // Sender text label
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'SENDER: ',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  TextSpan(
                    text: '$senderName ($senderMobile)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // EDIT pill button
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'EDIT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
        color: Color(0xFF94A3B8),
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  final String title;
  const _SubHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w600,
        color: Color(0xFF94A3B8),
      ),
    );
  }
}

class _LocationItem {
  final String name;
  final bool isNear;
  const _LocationItem({required this.name, required this.isNear});
}

class _LocationGrid extends StatelessWidget {
  final List<_LocationItem> items;
  final ValueChanged<String> onSelect;

  const _LocationGrid({
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        final itemWidth = (MediaQuery.of(context).size.width - 42) / 2;
        return InkWell(
          onTap: () => onSelect(item.name),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: itemWidth,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  item.isNear ? Icons.location_on_outlined : Icons.send_rounded,
                  color: item.isNear ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FareCard extends StatelessWidget {
  final bool quoting;
  final String? error;
  final dynamic quote;
  final VoidCallback onRetry;

  const _FareCard({
    required this.quoting,
    required this.error,
    required this.quote,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (quoting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (quote == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fare unavailable',
                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
            const SizedBox(height: 4),
            Text(
              error ?? 'Could not price this delivery.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('APPROX. DELIVERY FARE',
                        style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 0.7,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        )),
                    const SizedBox(height: 4),
                    Text(
                      'Rs ${quote.total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.inventory_2_outlined, color: TaxiColors.primary, size: 30),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Based on road travel of ${quote.distanceKm.toStringAsFixed(1)} km',
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5),
          ),
          Text(
            'Base fare covers ${quote.baseDistanceKm.toStringAsFixed(1)} km before extra charges',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            'Subtotal Rs ${quote.subtotal.toStringAsFixed(2)} + service tax '
            '${quote.serviceTaxPercentage.toStringAsFixed(2)}% (Rs ${quote.serviceTaxAmount.toStringAsFixed(2)})',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SuggestionTile({required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        radius: 16,
        backgroundColor: Color(0xFFE2E8F0),
        child: Icon(Icons.location_on_outlined, size: 17, color: Color(0xFF475569)),
      ),
      title: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
      subtitle: Text(subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
      onTap: onTap,
    );
  }
}
