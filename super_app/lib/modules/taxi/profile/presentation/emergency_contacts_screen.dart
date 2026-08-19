import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/design_system/components/ride/app_text_field.dart';
import 'package:superapp_user/design_system/components/ride/custom_app_bar.dart';
import 'package:superapp_user/design_system/components/ride/custom_bottom_sheet.dart';
import 'package:superapp_user/design_system/components/ride/empty_state.dart';
import 'package:superapp_user/design_system/components/ride/primary_button.dart';
import 'package:superapp_user/modules/taxi/profile/application/emergency_contacts_provider.dart';

class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(emergencyContactsProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Emergency contacts',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddSheet(context),
          ),
        ],
      ),
      body: contacts.isEmpty
          ? EmptyState(
              icon: Icons.shield_outlined,
              title: 'No emergency contacts',
              message: 'Add trusted contacts who can be notified during an SOS.',
              actionLabel: 'Add contact',
              onAction: () => _showAddSheet(context),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: TaxiColors.primary.withValues(alpha: 0.08),
                    child: Text(
                      contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: TaxiColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                  title: Text(contact.name),
                  subtitle: Text('${contact.relation} · ${contact.phone}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => ref.read(emergencyContactsProvider.notifier).remove(contact.id),
                  ),
                );
              },
            ),
    );
  }

  void _showAddSheet(BuildContext context) {
    CustomBottomSheet.show(
      context,
      title: 'Add emergency contact',
      child: const _AddContactForm(),
    );
  }
}

class _AddContactForm extends ConsumerStatefulWidget {
  const _AddContactForm();

  @override
  ConsumerState<_AddContactForm> createState() => _AddContactFormState();
}

class _AddContactFormState extends ConsumerState<_AddContactForm> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _relation = 'Family';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final r in ['Family', 'Friend', 'Other'])
              ChoiceChip(
                label: Text(r),
                selected: _relation == r,
                onSelected: (_) => setState(() => _relation = r),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(controller: _nameController, label: 'Name', hint: 'Contact name'),
        const SizedBox(height: 12),
        AppTextField(
          controller: _phoneController,
          label: 'Phone number',
          hint: '10-digit mobile number',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 20),
        TaxiPrimaryButton(label: 'Save contact', onPressed: _save),
      ],
    );
  }

  void _save() {
    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) return;
    ref.read(emergencyContactsProvider.notifier).add(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          relation: _relation,
        );
    Navigator.of(context).pop();
  }
}
