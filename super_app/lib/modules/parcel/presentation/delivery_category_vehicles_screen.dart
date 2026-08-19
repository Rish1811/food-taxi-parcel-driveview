import 'dart:convert' show Base64Decoder;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/design_system/components/ride/empty_state.dart';
import 'package:superapp_user/design_system/components/ride/loading_widget.dart';
import 'package:superapp_user/modules/taxi/home/application/home_providers.dart';
import 'package:superapp_user/modules/parcel/application/delivery_booking_controller.dart';
import 'package:superapp_user/modules/parcel/application/delivery_categories.dart';

/// Vehicles filed under one delivery card.
///
/// The category is fixed product taxonomy; the vehicles inside it are entirely
/// admin-driven — whatever the catalog has with this `delivery_category`.
class DeliveryCategoryVehiclesScreen extends ConsumerWidget {
  final String categoryId;
  const DeliveryCategoryVehiclesScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = deliveryCategoryById(categoryId);
    final vehiclesAsync = ref.watch(deliveryVehiclesByCategoryProvider(categoryId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PARCEL DELIVERY',
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
            Text(
              category?.title ?? 'Choose a vehicle',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
      body: vehiclesAsync.when(
        loading: () => const LoadingWidget(message: 'Loading vehicles…'),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load vehicles',
          message: 'Please check your connection and try again.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(allVehicleTypesProvider),
        ),
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return EmptyState(
              icon: category?.icon ?? Icons.local_shipping_outlined,
              title: 'No ${category?.title ?? 'vehicles'} available',
              message:
                  'No vehicle is set up for this category yet. Please choose another option.',
              actionLabel: 'Go back',
              onAction: () => Navigator.of(context).maybePop(),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            itemCount: vehicles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              return _VehicleRow(
                name: vehicle.name,
                subtitle: vehicle.shortDescription.isNotEmpty
                    ? vehicle.shortDescription
                    : vehicle.description,
                capacity: vehicle.capacity,
                imageSource: vehicle.image.isNotEmpty ? vehicle.image : vehicle.mapIcon,
                onTap: () {
                  ref.read(deliveryBookingProvider.notifier).selectVehicle(
                        id: vehicle.id,
                        name: vehicle.name,
                      );
                  context.push('/parcel/addresses');
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final int capacity;
  final String imageSource;
  final VoidCallback onTap;

  const _VehicleRow({
    required this.name,
    required this.subtitle,
    required this.capacity,
    required this.imageSource,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              height: 52,
              child: _VehicleArt(source: imageSource),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                  if (capacity > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Up to $capacity kg',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: TaxiColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

/// Catalog art arrives as a URL or an inline base64 data URI.
class _VehicleArt extends StatelessWidget {
  final String source;
  const _VehicleArt({required this.source});

  static const _fallback =
      Icon(Icons.local_shipping_outlined, size: 32, color: TaxiColors.primary);

  @override
  Widget build(BuildContext context) {
    if (source.isEmpty) return _fallback;

    if (source.startsWith('data:')) {
      final comma = source.indexOf(',');
      if (comma < 0) return _fallback;
      try {
        return Image.memory(
          const Base64Decoder().convert(source.substring(comma + 1)),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallback,
        );
      } catch (_) {
        return _fallback;
      }
    }

    return CachedNetworkImage(
      imageUrl: source,
      fit: BoxFit.contain,
      errorWidget: (_, __, ___) => _fallback,
    );
  }
}
