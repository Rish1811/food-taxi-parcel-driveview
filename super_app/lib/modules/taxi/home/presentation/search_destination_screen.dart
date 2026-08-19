import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/modules/taxi/taxi_constants.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/design_system/components/feedback/taxi_snackbar_utils.dart';
import 'package:superapp_user/modules/taxi/home/application/booking_controller.dart';
import 'package:superapp_user/modules/taxi/home/application/booking_state.dart';
import 'package:superapp_user/modules/taxi/home/application/home_providers.dart';
import 'package:superapp_user/modules/taxi/home/application/recent_searches_provider.dart';

class _GeoResult {
  final String title;
  final String address;
  final double lat;
  final double lng;
  final String? placeId;
  const _GeoResult({
    required this.title,
    required this.address,
    required this.lat,
    required this.lng,
    this.placeId,
  });
}

enum FieldTargetType { pickup, drop, stop }

class FieldTarget {
  final FieldTargetType type;
  final int? stopIndex;
  const FieldTarget.pickup() : type = FieldTargetType.pickup, stopIndex = null;
  const FieldTarget.drop() : type = FieldTargetType.drop, stopIndex = null;
  const FieldTarget.stop(int index) : type = FieldTargetType.stop, stopIndex = index;
}

class SearchDestinationScreen extends ConsumerStatefulWidget {
  const SearchDestinationScreen({super.key});

  @override
  ConsumerState<SearchDestinationScreen> createState() => _SearchDestinationScreenState();
}

class _SearchDestinationScreenState extends ConsumerState<SearchDestinationScreen> {
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final List<TextEditingController> _stopControllers = [];
  final List<BookingLocation?> _stops = [];

  Timer? _debounce;
  List<_GeoResult> _results = [];
  bool _searching = false;
  FieldTarget _activeTarget = const FieldTarget.drop();

  BookingLocation? _pickup;
  BookingLocation? _drop;
  String _sessionToken = '';

  void _ensureSessionToken() {
    if (_sessionToken.isEmpty) {
      _sessionToken =
          '${DateTime.now().millisecondsSinceEpoch}_${1000 + (DateTime.now().microsecondsSinceEpoch % 9000)}';
    }
  }

  @override
  void initState() {
    super.initState();
    _prefillCurrentLocation();
  }

  Future<void> _prefillCurrentLocation() async {
    final address = await ref.read(currentAddressProvider.future);
    final position = await ref.read(currentPositionProvider.future);
    if (!mounted) return;
    final lat = position?.latitude ?? 22.7196;
    final lng = position?.longitude ?? 75.8577;
    final finalAddress = address.isNotEmpty ? address : 'Current Location';
    setState(() {
      _pickup = BookingLocation(lat: lat, lng: lng, address: finalAddress);
      _pickupController.text = finalAddress;
    });
  }

  int? _findFirstEmptyStopIndex() {
    for (int i = 0; i < _stopControllers.length; i++) {
      if (i >= _stops.length || _stops[i] == null || _stopControllers[i].text.trim().isEmpty) {
        return i;
      }
    }
    return null;
  }

  void _addStop() {
    setState(() {
      final controller = TextEditingController();
      _stopControllers.add(controller);
      _stops.add(null);
      _activeTarget = FieldTarget.stop(_stopControllers.length - 1);
    });
    SnackbarUtils.info(context, 'Stop added after drop location');
  }

  void _removeStop(int index) {
    final removedController = _stopControllers[index];
    setState(() {
      _stopControllers.removeAt(index);
      _stops.removeAt(index);
      if (_activeTarget.type == FieldTargetType.stop && _activeTarget.stopIndex == index) {
        _activeTarget = const FieldTarget.drop();
      } else if (_activeTarget.type == FieldTargetType.stop &&
          _activeTarget.stopIndex != null &&
          _activeTarget.stopIndex! > index) {
        _activeTarget = FieldTarget.stop(_activeTarget.stopIndex! - 1);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      removedController.dispose();
    });
  }

  void _reorderDestinations(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      if (oldIndex == newIndex) return;

      final allLocations = <BookingLocation?>[_drop, ..._stops];
      final movedLocation = allLocations.removeAt(oldIndex);
      allLocations.insert(newIndex, movedLocation);

      _drop = allLocations[0];
      _dropController.text = _drop?.address ?? '';

      for (int i = 0; i < _stops.length; i++) {
        _stops[i] = allLocations[i + 1];
        _stopControllers[i].text = _stops[i]?.address ?? '';
      }
    });

    if (_pickup != null && _drop != null) {
      final validStops = _stops.whereType<BookingLocation>().toList();
      ref.read(bookingControllerProvider.notifier)
        ..setPickup(_pickup!)
        ..setStops(validStops)
        ..setDrop(_drop!);
    }
  }

  void _swapLocations(int indexA, int indexB) {
    if (indexA == indexB) return;
    _reorderDestinations(indexA, indexB > indexA ? indexB : indexB + 1);
  }

  Widget _buildTimelineDot({
    required Color color,
    required bool showTopLine,
    required bool showBottomLine,
    required bool isDark,
  }) {
    final lineColor = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
    return SizedBox(
      width: 24,
      height: 44,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              width: 2,
              color: showTopLine ? lineColor : Colors.transparent,
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.5),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
            ),
            child: Center(
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: 2,
              color: showBottomLine ? lineColor : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    _ensureSessionToken();

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {
          'input': trimmed,
          'key': TaxiConstants.mapKey,
          'sessiontoken': _sessionToken,
          'components': 'country:in',
        },
      );

      if (response.data != null && response.data['status'] == 'OK') {
        final predictions = response.data['predictions'] as List;
        final geoResults = predictions.map((item) {
          final description = (item['description'] ?? '') as String;
          final mainText =
              (item['structured_formatting']?['main_text'] ?? description.split(',').first) as String;
          final placeId = (item['place_id'] ?? '') as String;
          return _GeoResult(
            title: mainText,
            address: description,
            placeId: placeId,
            lat: 0,
            lng: 0,
          );
        }).toList();

        if (mounted) {
          setState(() {
            _results = geoResults;
            _searching = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Google Places Autocomplete REST error: $e');
    }

    try {
      final locations = await locationFromAddress(trimmed);
      if (mounted && locations.isNotEmpty) {
        setState(() {
          _results = locations
              .take(6)
              .map((l) => _GeoResult(
                    title: trimmed.split(',').first,
                    address: trimmed,
                    lat: l.latitude,
                    lng: l.longitude,
                  ))
              .toList();
          _searching = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Native geocoding error: $e');
    }

    if (mounted) {
      setState(() {
        _results = [];
        _searching = false;
      });
      SnackbarUtils.info(context, 'No matching places found');
    }
  }

  Future<void> _selectResult(_GeoResult result) async {
    double lat = result.lat;
    double lng = result.lng;

    if (result.placeId != null && result.placeId!.isNotEmpty) {
      try {
        final dio = Dio();
        final response = await dio.get(
          'https://maps.googleapis.com/maps/api/place/details/json',
          queryParameters: {
            'place_id': result.placeId,
            'key': TaxiConstants.mapKey,
            'sessiontoken': _sessionToken,
            'fields': 'formatted_address,geometry',
          },
        );

        if (response.data != null && response.data['status'] == 'OK') {
          final loc = response.data['result']['geometry']['location'];
          lat = (loc['lat'] as num).toDouble();
          lng = (loc['lng'] as num).toDouble();
        }
      } catch (e) {
        debugPrint('Place Details fetch error: $e');
      } finally {
        _sessionToken = '';
      }
    }

    if (lat == 0 && lng == 0) {
      if (mounted) {
        SnackbarUtils.info(context, 'Could not locate that place. Please pick another.');
      }
      return;
    }

    final location = BookingLocation(lat: lat, lng: lng, address: result.address);
    ref.read(recentSearchesProvider.notifier).add(address: result.address, lat: lat, lng: lng);

    setState(() {
      if (_activeTarget.type == FieldTargetType.pickup) {
        _pickup = location;
        _pickupController.text = result.address;
        if (_drop == null) {
          _activeTarget = const FieldTarget.drop();
        }
      } else if (_activeTarget.type == FieldTargetType.drop) {
        _drop = location;
        _dropController.text = result.address;
        final nextEmpty = _findFirstEmptyStopIndex();
        if (nextEmpty != null) {
          _activeTarget = FieldTarget.stop(nextEmpty);
        }
      } else if (_activeTarget.type == FieldTargetType.stop &&
          _activeTarget.stopIndex != null &&
          _activeTarget.stopIndex! < _stops.length) {
        final idx = _activeTarget.stopIndex!;
        _stops[idx] = location;
        _stopControllers[idx].text = result.address;
        final nextEmpty = _findFirstEmptyStopIndex();
        if (nextEmpty != null) {
          _activeTarget = FieldTarget.stop(nextEmpty);
        }
      }
      _results = [];
    });

    _tryProceedToRideTypes();
  }

  void _tryProceedToRideTypes({bool isExplicitContinue = false}) {
    if (_pickup == null || _drop == null) {
      if (isExplicitContinue) {
        if (_pickup == null) {
          SnackbarUtils.info(context, 'Please enter pickup location');
        } else {
          SnackbarUtils.info(context, 'Please enter drop location');
        }
      }
      return;
    }

    final firstEmptyStopIdx = _findFirstEmptyStopIndex();
    final allStopsFilled = firstEmptyStopIdx == null;

    if (!allStopsFilled) {
      if (isExplicitContinue) {
        setState(() {
          _activeTarget = FieldTarget.stop(firstEmptyStopIdx);
        });
        if (mounted) {
          SnackbarUtils.info(context, 'Please enter location for Stop ${firstEmptyStopIdx + 1}');
        }
      }
      return;
    }

    final validStops = _stops.whereType<BookingLocation>().toList();
    ref.read(bookingControllerProvider.notifier)
      ..setPickup(_pickup!)
      ..setStops(validStops)
      ..setDrop(_drop!)
      ..goToStep(BookingStep.selectingVehicle);

    if (mounted) {
      context.push('/taxi/vehicles');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pickupController.dispose();
    _dropController.dispose();
    for (final c in _stopControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    final recentSearches = ref.watch(recentSearchesProvider);
    final displayPlaces = recentSearches
        .map((place) => _GeoResult(
              title: place.address.split(',').first,
              address: place.address,
              lat: place.lat,
              lng: place.lng,
            ))
        .toList();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // --- TOP HEADER BAR ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => context.pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 24),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Drop',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // --- ROUTE INPUT CARD: Pickup -> Drop -> Stops (After Drop) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Pickup Row
                    SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          _buildTimelineDot(
                            color: const Color(0xFF10B981),
                            showTopLine: false,
                            showBottomLine: true,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _pickupController,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: textPrimary,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 4),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                fillColor: Colors.transparent,
                                hintText: 'Pickup location',
                                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                              ),
                              onTap: () => setState(() {
                                _activeTarget = const FieldTarget.pickup();
                              }),
                              onChanged: (v) {
                                setState(() {
                                  _activeTarget = const FieldTarget.pickup();
                                });
                                _onQueryChanged(v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: dividerColor),

                    // 2. Reorderable Destinations List (Drop + Stops)
                    // ignore: deprecated_member_use
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      // ignore: deprecated_member_use
                    onReorder: _reorderDestinations,
                      itemCount: 1 + _stopControllers.length,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // Drop Location Row
                          return Column(
                            key: const ValueKey('drop_location_row'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 44,
                                child: Row(
                                  children: [
                                    _buildTimelineDot(
                                      color: const Color(0xFFFF5C2B),
                                      showTopLine: true,
                                      showBottomLine: _stopControllers.isNotEmpty,
                                      isDark: isDark,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _dropController,
                                        autofocus: _stopControllers.isEmpty,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: textPrimary,
                                        ),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          fillColor: Colors.transparent,
                                          hintText: 'Drop location',
                                          hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                                        ),
                                        onTap: () => setState(() {
                                          _activeTarget = const FieldTarget.drop();
                                        }),
                                        onChanged: (v) {
                                          setState(() {
                                            _activeTarget = const FieldTarget.drop();
                                          });
                                          _onQueryChanged(v);
                                        },
                                      ),
                                    ),
                                    if (_stopControllers.isNotEmpty)
                                      ReorderableDragStartListener(
                                        index: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          child: const Icon(
                                            Icons.swap_vert_rounded,
                                            color: Color(0xFFFF5C2B),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Stop Row (index - 1)
                          final i = index - 1;
                          return Column(
                            key: ValueKey('stop_row_$i'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Divider(height: 1, thickness: 1, color: dividerColor),
                              SizedBox(
                                height: 44,
                                child: Row(
                                  children: [
                                    _buildTimelineDot(
                                      color: const Color(0xFF3B82F6),
                                      showTopLine: true,
                                      showBottomLine: i < _stopControllers.length - 1,
                                      isDark: isDark,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _stopControllers[i],
                                        autofocus: i == _stopControllers.length - 1,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: textPrimary,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          fillColor: Colors.transparent,
                                          hintText: 'Stop ${i + 1} location',
                                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                                        ),
                                        onTap: () => setState(() {
                                          _activeTarget = FieldTarget.stop(i);
                                        }),
                                        onChanged: (v) {
                                          setState(() {
                                            _activeTarget = FieldTarget.stop(i);
                                          });
                                          _onQueryChanged(v);
                                        },
                                      ),
                                    ),
                                    // Swap / Drag & Drop Handle
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: InkWell(
                                        onTap: () => _swapLocations(0, index),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          child: const Icon(
                                            Icons.swap_vert_rounded,
                                            color: Color(0xFFEF4444),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Close Button
                                    GestureDetector(
                                      onTap: () => _removeStop(i),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4.0),
                                        child: Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // --- ACTION SHORTCUT CHIPS (Select on map / Add stops) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // "Select on map" Chip (Left)
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => context.push('/taxi/pick-on-map?type=drop').then(_handleMapPickerResult),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: textPrimary, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Select on map',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // "Add stops" Chip (Right Side)
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _addStop,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add_circle, color: textPrimary, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Add stops',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1, color: dividerColor),

            if (_searching) const LinearProgressIndicator(minHeight: 2, color: TaxiColors.primaryOrange),

            // --- RECENT SEARCHES & LIVE RESULTS LIST ---
            Expanded(
              child: _results.isNotEmpty
                  ? ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _results.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: dividerColor),
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        return _DestinationListItem(
                          item: item,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          onTap: () => _selectResult(item),
                        );
                      },
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: displayPlaces.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: dividerColor),
                      itemBuilder: (context, index) {
                        final item = displayPlaces[index];
                        return _DestinationListItem(
                          item: item,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          onTap: () => _selectResult(item),
                        );
                      },
                    ),
            ),

            // --- BOTTOM CONTINUE BUTTON BAR ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5C2B),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _tryProceedToRideTypes(isExplicitContinue: true),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMapPickerResult(dynamic result) {
    if (result is! Map) return;
    final location = BookingLocation(
      lat: result['lat'] as double,
      lng: result['lng'] as double,
      address: result['address'] as String,
    );
    setState(() {
      if (result['type'] == 'pickup') {
        _pickup = location;
        _pickupController.text = location.address;
      } else {
        _drop = location;
        _dropController.text = location.address;
      }
    });

    _tryProceedToRideTypes();
  }
}

class _DestinationListItem extends StatelessWidget {
  final _GeoResult item;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  const _DestinationListItem({
    required this.item,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              // Left History Clock Icon
              Icon(Icons.history_rounded, color: textSecondary, size: 22),
              const SizedBox(width: 14),

              // Title & Address Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Favorite Heart Icon
              GestureDetector(
                onTap: () {
                  SnackbarUtils.info(context, 'Saved to favorite places');
                },
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.favorite_border_rounded, color: Color(0xFF94A3B8), size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
