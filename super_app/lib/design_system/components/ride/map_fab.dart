import 'package:flutter/material.dart';

class MapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool mini;

  const MapFab({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: UniqueKey(),
      mini: mini,
      tooltip: tooltip,
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.primary,
      elevation: 3,
      onPressed: onPressed,
      child: Icon(icon),
    );
  }
}
