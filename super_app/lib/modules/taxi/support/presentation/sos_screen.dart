import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/design_system/components/ride/app_text_field.dart';
import 'package:superapp_user/design_system/components/ride/custom_app_bar.dart';
import 'package:superapp_user/design_system/components/ride/primary_button.dart';
import 'package:superapp_user/modules/taxi/support/application/support_providers.dart';

class SosScreen extends ConsumerStatefulWidget {
  final String? rideId;
  const SosScreen({super.key, this.rideId});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  final _notesController = TextEditingController();
  bool _sending = false;
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Emergency SOS'),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _sent ? _buildSentState(context) : _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TaxiColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.emergency_share_rounded, color: TaxiColors.error, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'This alerts our safety team with your live location${widget.rideId != null ? ' and current trip' : ''}. Use only in a genuine emergency.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppTextField(
          controller: _notesController,
          label: 'What is happening? (optional)',
          hint: 'Add any details for our safety team',
          maxLines: 4,
        ),
        const Spacer(),
        TaxiPrimaryButton(
          label: _sending ? 'Sending alert…' : 'Send SOS alert',
          isLoading: _sending,
          onPressed: _sending ? null : _sendSos,
        ),
      ],
    );
  }

  Widget _buildSentState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 88,
            width: 88,
            decoration: const BoxDecoration(color: TaxiColors.success, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 20),
          Text('Alert sent', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Our safety team has been notified with your location and will reach out shortly.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Go back')),
        ],
      ),
    );
  }

  Future<void> _sendSos() async {
    setState(() => _sending = true);
    try {
      final locationService = ref.read(taxiLocationServiceProvider);
      final permission = await locationService.ensurePermission();
      double lat = 0;
      double lng = 0;
      if (permission.granted) {
        final position = await locationService.getCurrentPosition();
        lat = position.latitude;
        lng = position.longitude;
      }
      await ref.read(supportRepositoryProvider).triggerSos(
            rideId: widget.rideId,
            lat: lat,
            lng: lng,
            notes: _notesController.text.trim(),
          );
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send alert. Please call emergency services directly if needed.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
