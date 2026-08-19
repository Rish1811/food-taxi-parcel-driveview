import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/shared/search/presentation/viewmodels/search_viewmodel.dart';

/// Animated modal dialog displayed during Voice Search (Mic).
/// Returns [Future<String?>] containing the recognized query, or null if canceled.
class VoiceSearchDialog extends ConsumerStatefulWidget {
  const VoiceSearchDialog({super.key});

  static bool _isOpen = false;

  static Future<String?> show(BuildContext context) async {
    if (_isOpen) return null;
    _isOpen = true;
    developer.log('[VOICE] Mic tapped', name: 'VOICE');
    try {
      final String? result = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => const VoiceSearchDialog(),
      );
      return result;
    } catch (e, stack) {
      developer.log('[VOICE] Caught exception in showModalBottomSheet: $e\n$stack', name: 'VOICE');
      return null;
    } finally {
      _isOpen = false;
    }
  }

  @override
  ConsumerState<VoiceSearchDialog> createState() => _VoiceSearchDialogState();
}

class _VoiceSearchDialogState extends ConsumerState<VoiceSearchDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isHandled = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    Future.microtask(() {
      ref.read(searchViewModelProvider.notifier).startVoiceSearch(
        onSpeechComplete: (recognizedText) {
          if (mounted && !_isHandled) {
            _onSpeechSuccess(recognizedText);
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleCancel() {
    if (_isHandled) return;
    _isHandled = true;
    developer.log('[VOICE] Cancel pressed', name: 'VOICE');
    ref.read(searchViewModelProvider.notifier).cancelVoiceSearch();
    developer.log('[VOICE] Bottom sheet closed', name: 'VOICE');
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(null);
    }
  }

  void _onSpeechSuccess(String text) {
    if (_isHandled) return;
    _isHandled = true;
    ref.read(searchViewModelProvider.notifier).stopVoiceSearch();
    developer.log('[VOICE] Bottom sheet closed', name: 'VOICE');
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(text.trim());
    }
  }

  void _simulateVoiceSearch(String term) {
    Haptics.light();
    _onSpeechSuccess(term);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final searchState = ref.watch(searchViewModelProvider);

    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!_isHandled) {
          _isHandled = true;
          developer.log('[VOICE] Cancel pressed', name: 'VOICE');
          ref.read(searchViewModelProvider.notifier).cancelVoiceSearch();
          developer.log('[VOICE] Bottom sheet closed', name: 'VOICE');
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 24.h),

            // Listening Pulse Mic Avatar
            GestureDetector(
              onTap: () {
                if (!searchState.isListening) {
                  Haptics.light();
                  ref.read(searchViewModelProvider.notifier).startVoiceSearch(
                    onSpeechComplete: (text) {
                      if (mounted && !_isHandled) {
                        _onSpeechSuccess(text);
                      }
                    },
                  );
                }
              },
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: searchState.isListening ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 80.r,
                      height: 80.r,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 60.r,
                          height: 60.r,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            searchState.isListening ? Icons.mic : Icons.mic_none,
                            color: Colors.white,
                            size: 32.sp,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 18.h),

            Text(
              searchState.isListening
                  ? 'Listening...'
                  : (searchState.speechError != null
                      ? 'Voice Search Unavailable'
                      : (searchState.recognizedText.isNotEmpty
                          ? 'Recognized!'
                          : 'Processing...')),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            SizedBox(height: 8.h),

            Text(
              searchState.speechError ??
                  (searchState.recognizedText.isNotEmpty
                      ? '"${searchState.recognizedText}"'
                      : 'Say something like "Burger", "Pizza", or "KFC"'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5.sp,
                color: searchState.speechError != null
                    ? AppColors.error
                    : secondaryTextColor,
                fontStyle: searchState.recognizedText.isNotEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
            SizedBox(height: 20.h),

            // Quick Voice Search suggestions if engine fails or for simulator testing
            if (searchState.speechError != null) ...[
              Text(
                'Or tap a quick search query:',
                style: TextStyle(fontSize: 12.sp, color: secondaryTextColor),
              ),
              SizedBox(height: 10.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                alignment: WrapAlignment.center,
                children: ['Burger', 'Pizza', 'KFC', 'Biryani', 'Paratha'].map((term) {
                  return ActionChip(
                    label: Text(term),
                    labelStyle: TextStyle(fontSize: 12.sp, color: textColor),
                    backgroundColor: isDark ? AppColors.cardDark : const Color(0xFFF4F5F7),
                    onPressed: () => _simulateVoiceSearch(term),
                  );
                }).toList(),
              ),
              SizedBox(height: 16.h),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 120.w,
                  child: OutlinedButton(
                    onPressed: _handleCancel,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      side: BorderSide(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (searchState.recognizedText.isNotEmpty) ...[
                  SizedBox(width: 16.w),
                  SizedBox(
                    width: 120.w,
                    child: ElevatedButton(
                      onPressed: () => _onSpeechSuccess(searchState.recognizedText),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: const Text(
                        'Search',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 10.h),
          ],
        ),
      ),
    );
  }
}
