import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/core/maps/app_map_style.dart';
import 'package:superapp_user/design_system/components/ride/primary_button.dart';
import 'package:superapp_user/modules/taxi/home/application/home_providers.dart';

const _fallbackLatLng = LatLng(22.7196, 75.8577); // Indore center

class MapPickerScreen extends ConsumerStatefulWidget {
  final String type; // 'pickup' or 'drop'

  const MapPickerScreen({super.key, required this.type});

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  GoogleMapController? _controller;
  LatLng _center = _fallbackLatLng;
  String _address = 'Move the map to set location';
  bool _resolving = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _initPosition();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initPosition() async {
    final position = await ref.read(currentPositionProvider.future);
    if (position == null || !mounted) return;
    final target = LatLng(position.latitude, position.longitude);
    setState(() => _center = target);
    _controller?.animateCamera(CameraUpdate.newLatLngZoom(target, 16.5));
  }

  Future<void> _recenterToCurrentLocation() async {
    final position = await ref.read(currentPositionProvider.future);
    if (position == null || !mounted) return;
    final target = LatLng(position.latitude, position.longitude);
    setState(() => _center = target);
    _controller?.animateCamera(CameraUpdate.newLatLngZoom(target, 16.5));
  }

  Future<void> _resolveAddress(LatLng point) async {
    if (!mounted) return;
    setState(() => _resolving = true);
    try {
      final service = ref.read(taxiLocationServiceProvider);
      final addr = await service.getAddressFromCoordinates(point.latitude, point.longitude);
      if (mounted) {
        setState(() => _address = addr.isNotEmpty
            ? addr
            : '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _address =
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}');
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _onCameraIdle() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      _resolveAddress(_center);
    });
  }

  void _onCameraMove(CameraPosition position) {
    _debounceTimer?.cancel();
    _center = position.target;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPickup = widget.type == 'pickup';
    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            style: AppMapStyle.muted,
            initialCameraPosition: CameraPosition(target: _center, zoom: 16.5),
            onMapCreated: (c) {
              _controller = c;
              _initPosition();
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
          ),

          // --- CENTER MAP LOCATION PIN POINTER ---
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPickup ? const Color(0xFF10B981) : const Color(0xFFFF5200),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: Text(
                      isPickup ? 'Set Pickup' : 'Set Drop',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    Icons.location_on_rounded,
                    size: 46,
                    color: isPickup ? const Color(0xFF10B981) : const Color(0xFFFF5200),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- TOP LEFT BACK BUTTON ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: cardBgColor,
                shape: const CircleBorder(),
                elevation: 3,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textPrimary),
                  ),
                ),
              ),
            ),
          ),

          // --- CURRENT LOCATION FAB BUTTON ---
          Positioned(
            bottom: 185,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'recenter_map_picker_fab',
              backgroundColor: cardBgColor,
              elevation: 4,
              onPressed: _recenterToCurrentLocation,
              child: const Icon(
                Icons.my_location_rounded,
                color: Color(0xFFFF5200),
                size: 24,
              ),
            ),
          ),

          // --- BOTTOM ADDRESS & CONFIRM CARD ---
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPickup ? 'Set pickup point' : 'Set drop point',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _resolving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF5200)),
                        )
                      : Text(
                          _address,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                  const SizedBox(height: 16),
                  TaxiPrimaryButton(
                    label: 'Confirm ${isPickup ? 'pickup' : 'drop'}',
                    onPressed: _resolving
                        ? null
                        : () => Navigator.of(context).pop({
                              'type': widget.type,
                              'lat': _center.latitude,
                              'lng': _center.longitude,
                              'address': _address,
                            }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
