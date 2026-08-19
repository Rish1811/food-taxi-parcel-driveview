import 'package:flutter/material.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/core/utils/taxi_formatters.dart';

class VehicleCard extends StatelessWidget {
  final String name;
  final String description;
  final IconData icon;
  final double price;
  final String eta;
  final bool selected;
  final VoidCallback onTap;
  final int? seats;

  const VehicleCard({
    super.key,
    required this.name,
    required this.description,
    required this.icon,
    required this.price,
    required this.eta,
    required this.selected,
    required this.onTap,
    this.seats,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? TaxiColors.primary.withValues(alpha: 0.08)
                : scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? scheme.primary : TaxiColors.lightBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: TaxiColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: TaxiColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: Theme.of(context).textTheme.titleMedium),
                        if (seats != null) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.person, size: 13, color: scheme.onSurface.withValues(alpha: 0.5)),
                          Text(' $seats', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(description, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      eta,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: TaxiColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                Formatters.currency(price),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
