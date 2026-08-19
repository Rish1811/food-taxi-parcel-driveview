import 'package:flutter/material.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:intl/intl.dart';

class RecentActivityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String pickup;
  final String drop;
  final DateTime date;
  final double fare;
  final String status;
  final String serviceType;
  final String? vehicleIconType;
  final VoidCallback onTap;

  const RecentActivityCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.pickup,
    required this.drop,
    required this.date,
    required this.fare,
    required this.status,
    required this.serviceType,
    this.vehicleIconType,
    required this.onTap,
  });

  Color _statusTextColor(bool isDark) {
    switch (status.toLowerCase()) {
      case 'completed':
        return isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
      case 'cancelled':
        return isDark ? const Color(0xFFF87171) : const Color(0xFFFF3B30);
      case 'scheduled':
        return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
      default:
        return TaxiColors.info;
    }
  }

  Color _statusBgColor(bool isDark) {
    switch (status.toLowerCase()) {
      case 'completed':
        return isDark ? const Color(0xFF064E3B) : const Color(0xFFE6F4EA);
      case 'cancelled':
        return isDark ? const Color(0xFF4C0519) : const Color(0xFFFFEBEB);
      case 'scheduled':
        return isDark ? const Color(0xFF0C4A6E) : const Color(0xFFE0F2FE);
      default:
        return isDark ? TaxiColors.darkBorder : const Color(0xFFF1F5F9);
    }
  }

  String _formatStatusLabel() {
    if (status.isEmpty) return 'COMPLETED';
    return status.toUpperCase();
  }

  Widget _buildVehicleIcon(bool isDark) {
    final isParcel = serviceType.toLowerCase().contains('parcel');
    final isTaxi = serviceType.toLowerCase().contains('taxi') || title.toLowerCase().contains('taxi');
    
    // Choose image asset based on type
    String imageAsset = 'assets/images/taxi/car.png';
    String badgeText = 'V';
    Color badgeColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8); // Grey badge
    
    if (isParcel) {
      imageAsset = 'assets/images/taxi/parcel.png';
      badgeText = 'DA';
      badgeColor = const Color(0xFFF59E0B); // Yellow/Orange badge
    } else if (isTaxi) {
      imageAsset = 'assets/images/taxi/auto_cat.png';
      badgeText = 'V';
      badgeColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    }

    final boxBg = isDark ? TaxiColors.darkSurface : Colors.white;
    final boxBorder = isDark ? TaxiColors.darkBorder : const Color(0xFFE2E8F0);
    final badgeBorderColor = isDark ? TaxiColors.darkCard : Colors.white;

    return Stack(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: boxBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: boxBorder, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              imageAsset,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                isParcel ? Icons.local_shipping_rounded : Icons.directions_car_rounded,
                color: isDark ? TaxiColors.darkTextSecondary : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badgeBorderColor, width: 1.5),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? TaxiColors.darkCard : Colors.white;
    final borderColor = isDark ? TaxiColors.darkBorder : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? TaxiColors.darkTextPrimary : const Color(0xFF0F172A);
    final textSecondary = isDark ? TaxiColors.darkTextSecondary : const Color(0xFF64748B);
    final subtitleColor = isDark ? TaxiColors.darkTextSecondary : const Color(0xFF94A3B8);

    final statusLabel = _formatStatusLabel();
    final statusColor = _statusTextColor(isDark);
    final statusBg = _statusBgColor(isDark);
    
    // Formatting date and time like "07 AUG" and "04:43 PM"
    final dateStr = DateFormat('dd MMM').format(date).toUpperCase();
    final timeStr = DateFormat('hh:mm a').format(date);
    
    // Generating subtitle in caps
    String finalSubtitle = subtitle.isEmpty ? '$serviceType BOOKING' : subtitle;
    if (finalSubtitle.toLowerCase() == 'ride' || finalSubtitle.toLowerCase() == 'taxi') {
        finalSubtitle = 'DRIVER TRIP';
    } else if (serviceType.toLowerCase().contains('parcel')) {
        finalSubtitle = 'DELIVERY BOOKING';
    }
    finalSubtitle = finalSubtitle.toUpperCase();

    // Fare formatting
    final formattedFare = fare > 0 ? 'Rs ${fare.toInt()}' : 'Rs 0';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Image + Titles + Fare
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildVehicleIcon(isDark),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          finalSubtitle,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: subtitleColor,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        formattedFare,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: textSecondary.withValues(alpha: 0.4),
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Location Row
              if (pickup.isNotEmpty || drop.isNotEmpty) ...[
                Text(
                  '$pickup${pickup.isNotEmpty && drop.isNotEmpty ? ' to ' : ''}$drop',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
              ],

              // Bottom Row: Date/Time + Status Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: textSecondary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: textSecondary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
