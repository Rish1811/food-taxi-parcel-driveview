import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/core/utils/taxi_formatters.dart';
import 'package:superapp_user/design_system/components/ride/app_bottom_navigation_bar.dart';
import 'package:superapp_user/design_system/components/ride/custom_app_bar.dart';
import 'package:superapp_user/design_system/components/ride/empty_state.dart';
import 'package:superapp_user/modules/rental/application/rental_providers.dart';
import 'package:superapp_user/modules/rental/data/models/rental_vehicle_model.dart';

class RentalVehiclesScreen extends ConsumerWidget {
  const RentalVehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(rentalVehiclesProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Rent a vehicle',
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.push('/rental'),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigationBar(currentIndex: 2),
      body: vehiclesAsync.when(
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return const EmptyState(
              icon: Icons.directions_car_outlined,
              title: 'No rental vehicles available',
              message: 'Check back later for self-drive and rental options.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: vehicles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) => _RentalVehicleCard(vehicle: vehicles[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load rental vehicles: $e')),
      ),
    );
  }
}

class _RentalVehicleCard extends StatelessWidget {
  final RentalVehicleModel vehicle;
  const _RentalVehicleCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final cheapest = vehicle.pricing.isEmpty
        ? null
        : vehicle.pricing.reduce((a, b) => a.price < b.price ? a : b);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/rental/vehicles/${vehicle.id}/book', extra: vehicle),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TaxiColors.lightBorder),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 72,
                  height: 72,
                  color: TaxiColors.primary.withValues(alpha: 0.08),
                  child: vehicle.image.isNotEmpty
                      ? Image.network(vehicle.image, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.directions_car_rounded))
                      : const Icon(Icons.directions_car_rounded, color: TaxiColors.primary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${vehicle.vehicleCategory} • ${vehicle.capacity} seats',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (cheapest != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'From ${Formatters.currency(cheapest.price)} / ${cheapest.durationHours}h',
                        style: const TextStyle(color: TaxiColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
