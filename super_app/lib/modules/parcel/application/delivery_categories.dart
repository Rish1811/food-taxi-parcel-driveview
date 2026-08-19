import 'package:flutter/material.dart';

/// The delivery cards a rider picks from before seeing vehicles.
///
/// Deliberately static in the app: these are a fixed product taxonomy, not
/// catalog data. Each `id` matches `DELIVERY_CATEGORY_TYPES` on the backend and
/// the admin panel's own option list — a vehicle's `delivery_category` is what
/// files it under one of these cards.
///
/// Keep in lockstep with:
///   Backend/src/modules/taxi/admin/models/Vehicle.js  (DELIVERY_CATEGORY_TYPES)
///   frontend/.../price-management/VehicleType.jsx     (DELIVERY_CATEGORY_OPTIONS)
class DeliveryCategory {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String assetImage;

  const DeliveryCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.assetImage = '',
  });
}

const kDeliveryCategories = <DeliveryCategory>[
  DeliveryCategory(
    id: 'trucks',
    title: 'Trucks',
    description: 'Heavy goods, loaders, and cargo-style delivery vehicles.',
    icon: Icons.local_shipping_rounded,
    assetImage: 'assets/images/taxi/truck_cat.png',
  ),
  DeliveryCategory(
    id: '2wheeler',
    title: '2 Wheeler',
    description: 'Fast lightweight parcel bikes and two-wheel delivery options.',
    icon: Icons.two_wheeler_rounded,
    assetImage: 'assets/images/taxi/scooter_cat.png',
  ),
  DeliveryCategory(
    id: 'auto',
    title: 'Auto',
    description: 'Classic three-wheeler Indian auto rickshaw for fast local parcel delivery.',
    icon: Icons.electric_rickshaw_rounded,
    assetImage: 'assets/images/taxi/auto_cat.png',
  ),
  DeliveryCategory(
    id: 'movers',
    title: 'Packers & Movers',
    description: 'Home shifting, helper-based, and larger move services.',
    icon: Icons.inventory_rounded,
    assetImage: 'assets/images/taxi/movers_cat.png',
  ),
];

DeliveryCategory? deliveryCategoryById(String id) {
  for (final category in kDeliveryCategories) {
    if (category.id == id) return category;
  }
  return null;
}
