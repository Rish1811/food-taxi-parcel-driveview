import 'package:superapp_user/modules/taxi/home/data/models/set_price_model.dart';

class FareBreakdown {
  final double baseFare;
  final double distanceFare;
  final double timeFare;
  final double serviceTax;
  final double total;

  const FareBreakdown({
    required this.baseFare,
    required this.distanceFare,
    required this.timeFare,
    required this.serviceTax,
    required this.total,
  });
}

class FareCalculator {
  /// Client-side fare estimate only — the backend recalculates and is
  /// authoritative at ride completion.
  static FareBreakdown estimate({
    required SetPriceModel pricing,
    required double distanceMeters,
    required double durationSeconds,
  }) {
    final distanceKm = distanceMeters / 1000;
    final durationMinutes = durationSeconds / 60;
    final chargeableKm = (distanceKm - pricing.baseDistanceKm).clamp(0, double.infinity);

    final baseFare = pricing.basePrice;
    final distanceFare = chargeableKm * pricing.pricePerDistance;
    final timeFare = durationMinutes * pricing.timePrice;
    final subtotal = baseFare + distanceFare + timeFare;
    final serviceTax = subtotal * (pricing.serviceTaxPercent / 100);
    final total = (subtotal + serviceTax).clamp(pricing.basePrice, double.infinity);

    return FareBreakdown(
      baseFare: baseFare,
      distanceFare: distanceFare,
      timeFare: timeFare,
      serviceTax: serviceTax,
      total: double.parse(total.toStringAsFixed(0)),
    );
  }
}
