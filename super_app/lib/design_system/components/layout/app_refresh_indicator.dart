import 'package:flutter/material.dart';
import 'package:superapp_user/core/audio/refresh_audio_player.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';

/// A unified pull-to-refresh wrapper for the entire application.
/// Ensures:
/// 1. Only one refresh can happen at a time (debouncing duplicate requests).
/// 2. Plays a premium refresh sound safely exactly once per pull.
/// 3. Maintains a standard, smooth Material refresh indicator visual.
class AppRefreshIndicator extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  State<AppRefreshIndicator> createState() => _AppRefreshIndicatorState();
}

class _AppRefreshIndicatorState extends State<AppRefreshIndicator> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Preload audio so there's no stutter when pulled
    RefreshAudioPlayer().init();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return; // Prevent duplicate requests
    
    _isRefreshing = true;
    
    // Play the audio for the premium feel
    RefreshAudioPlayer().play();

    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        _isRefreshing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? AppColors.surfaceDark 
          : Colors.white,
      strokeWidth: 2.5,
      displacement: 40.0,
      onRefresh: _handleRefresh,
      child: widget.child,
    );
  }
}
