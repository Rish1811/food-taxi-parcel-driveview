import 'package:flutter/material.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';

class DriverCard extends StatelessWidget {
  final String name;
  final String vehicleModel;
  final String vehicleNumber;
  final double rating;
  final String? photoUrl;
  final VoidCallback? onCall;
  final VoidCallback? onChat;

  const DriverCard({
    super.key,
    required this.name,
    required this.vehicleModel,
    required this.vehicleNumber,
    required this.rating,
    this.photoUrl,
    this.onCall,
    this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TaxiColors.lightBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: TaxiColors.primary.withValues(alpha: 0.1),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null
                ? const Icon(Icons.person, color: TaxiColors.primary)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '$vehicleModel • $vehicleNumber',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 16, color: TaxiColors.accentDark),
                    const SizedBox(width: 3),
                    Text(rating.toStringAsFixed(1), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          if (onChat != null)
            _RoundIconButton(icon: Icons.chat_bubble_rounded, onTap: onChat!),
          if (onCall != null) ...[
            const SizedBox(width: 8),
            _RoundIconButton(icon: Icons.call_rounded, onTap: onCall!, filled: true),
          ],
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _RoundIconButton({required this.icon, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? TaxiColors.success : TaxiColors.primary.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 18, color: filled ? Colors.white : TaxiColors.primary),
        ),
      ),
    );
  }
}
