import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/modules/parcel/application/delivery_booking_controller.dart';

/// Sender & receiver capture, shown over the address screen.
///
/// Both contacts are mandatory server-side (the driver calls them at each end),
/// so this validates before it will save rather than failing at booking time.
class DeliveryContactsSheet extends ConsumerStatefulWidget {
  const DeliveryContactsSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const DeliveryContactsSheet(),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<DeliveryContactsSheet> createState() => _DeliveryContactsSheetState();
}

class _DeliveryContactsSheetState extends ConsumerState<DeliveryContactsSheet> {
  late final TextEditingController _senderName;
  late final TextEditingController _senderPhone;
  late final TextEditingController _receiverName;
  late final TextEditingController _receiverPhone;

  bool _sameAsSender = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = ref.read(deliveryBookingProvider);
    _senderName = TextEditingController(text: state.senderName);
    _senderPhone = TextEditingController(text: state.senderMobile);
    _receiverName = TextEditingController(text: state.receiverName);
    _receiverPhone = TextEditingController(text: state.receiverMobile);
  }

  @override
  void dispose() {
    _senderName.dispose();
    _senderPhone.dispose();
    _receiverName.dispose();
    _receiverPhone.dispose();
    super.dispose();
  }

  void _applySameAsSender(bool value) {
    setState(() {
      _sameAsSender = value;
      if (value) {
        _receiverName.text = _senderName.text;
        _receiverPhone.text = _senderPhone.text;
      }
    });
  }

  void _save() {
    final senderName = _senderName.text.trim();
    final senderPhone = _senderPhone.text.trim();
    final receiverName = _receiverName.text.trim();
    final receiverPhone = _receiverPhone.text.trim();

    if (senderName.isEmpty || senderPhone.length < 10) {
      setState(() => _error = 'Enter the sender name and a 10-digit mobile number');
      return;
    }
    if (receiverName.isEmpty || receiverPhone.length < 10) {
      setState(() => _error = 'Enter the receiver name and a 10-digit mobile number');
      return;
    }

    ref.read(deliveryBookingProvider.notifier).setContacts(
          senderName: senderName,
          senderMobile: senderPhone,
          receiverName: receiverName,
          receiverMobile: receiverPhone,
        );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 16,
        bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'BOOKING DETAILS',
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const Text(
              'Sender & receiver',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            const _SectionLabel(icon: Icons.person_outline, label: 'Sender', color: TaxiColors.primary),
            const SizedBox(height: 8),
            _Field(controller: _senderName, hint: 'Sender name'),
            const SizedBox(height: 10),
            const Text('MOBILE NUMBER', style: _labelStyle),
            const SizedBox(height: 6),
            _Field(controller: _senderPhone, hint: '10-digit mobile number', phone: true),
            const SizedBox(height: 20),
            const _SectionLabel(icon: Icons.location_on_outlined, label: 'Receiver', color: Color(0xFFEF4444)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _applySameAsSender(!_sameAsSender),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _sameAsSender ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 20,
                      color: TaxiColors.primary,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Same as Sender',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text("Use sender's name and mobile for receiver",
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _Field(controller: _receiverName, hint: 'Receiver name', enabled: !_sameAsSender),
            const SizedBox(height: 10),
            const Text('MOBILE NUMBER', style: _labelStyle),
            const SizedBox(height: 6),
            _Field(
              controller: _receiverPhone,
              hint: '10-digit mobile number',
              phone: true,
              enabled: !_sameAsSender,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12.5)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _save,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Save Details', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(width: 6),
                    Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _labelStyle = TextStyle(
  fontSize: 9.5,
  letterSpacing: 0.7,
  fontWeight: FontWeight.w600,
  color: Color(0xFF94A3B8),
);

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionLabel({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool phone;
  final bool enabled;

  const _Field({
    required this.controller,
    required this.hint,
    this.phone = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: phone ? TextInputType.phone : TextInputType.name,
      inputFormatters: phone
          ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]
          : null,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }
}
