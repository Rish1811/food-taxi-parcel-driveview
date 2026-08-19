import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/features/work_mode/data/driver_availability_repository.dart';

const _taxiBlue = Color(0xFF1B6FF3);

/// Outcome of the pre-online selfie check.
class SelfieGateResult {
  const SelfieGateResult({required this.proceed, this.imageUrl});

  /// False when the driver backed out — the caller must not go online.
  final bool proceed;

  /// Uploaded selfie URL, or null when the server already has today's.
  final String? imageUrl;

  static const cancelled = SelfieGateResult(proceed: false);
  static const notRequired = SelfieGateResult(proceed: true);
}

/// Collects today's selfie if the driver still owes one, before going online.
///
/// The taxi backend rejects `PATCH /taxi/drivers/online` with
/// *"A selfie is required before going online today"* until one is on file for
/// the current date. Asking the server rather than tracking it locally means a
/// driver who already took one on another device isn't asked twice.
///
/// Returns [SelfieGateResult.notRequired] for a driver in Food-only mode — the
/// food availability endpoint has no such requirement, and prompting for a
/// selfie they don't need is the fastest way to make the toggle feel broken.
Future<SelfieGateResult> ensureOnlineSelfie(
  BuildContext context,
  WidgetRef ref, {
  required bool needsRides,
}) async {
  if (!needsRides) return SelfieGateResult.notRequired;

  final repository = ref.read(driverAvailabilityRepositoryProvider);
  final status = await repository.selfieStatus();
  final required = status.when(
    success: (s) => s.needed,
    // Unreachable server: let the driver go online anyway. The food half still
    // works, and goOnline's own error surfaces the taxi half honestly.
    failure: (_) => false,
  );
  if (!required || !context.mounted) return SelfieGateResult.notRequired;

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      title: const Text('Take today\'s selfie'),
      content: const Text(
        'Ride bookings need one photo of you at the start of each day. '
        'It takes a few seconds and is only asked once today.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Not now'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _taxiBlue,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Open camera'),
        ),
      ],
    ),
  );

  // "Not now" is not a cancel: the driver still goes online for food, and only
  // forfeits rides until they take it.
  if (confirmed != true) return SelfieGateResult.notRequired;

  final shot = await ImagePicker().pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.front,
    imageQuality: 70,
    maxWidth: 1080,
  );
  if (shot == null || !context.mounted) return SelfieGateResult.notRequired;

  final upload = await repository.uploadSelfie(shot.path);
  if (!context.mounted) return SelfieGateResult.notRequired;

  return upload.when(
    success: (url) => SelfieGateResult(proceed: true, imageUrl: url),
    failure: (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selfie upload failed: ${error.message}')),
      );
      return SelfieGateResult.notRequired;
    },
  );
}
