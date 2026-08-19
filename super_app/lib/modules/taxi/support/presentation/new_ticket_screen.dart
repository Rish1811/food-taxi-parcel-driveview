import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/design_system/components/ride/app_text_field.dart';
import 'package:superapp_user/design_system/components/ride/custom_app_bar.dart';
import 'package:superapp_user/design_system/components/ride/primary_button.dart';
import 'package:superapp_user/modules/taxi/support/application/support_providers.dart';

class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({super.key});

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  final _messageController = TextEditingController();
  String? _selectedTitleId;
  String? _selectedTitle;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final titlesAsync = ref.watch(supportTitlesProvider);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Raise a ticket'),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What do you need help with?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            titlesAsync.when(
              data: (titles) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: titles
                    .map((t) => ChoiceChip(
                          label: Text(t.title),
                          selected: _selectedTitleId == t.id,
                          onSelected: (_) => setState(() {
                            _selectedTitleId = t.id;
                            _selectedTitle = t.title;
                          }),
                        ))
                    .toList(),
              ),
              loading: () => const SizedBox(
                height: 32,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: _messageController,
              label: 'Describe your issue',
              hint: 'Tell us what happened…',
              maxLines: 6,
            ),
            const Spacer(),
            TaxiPrimaryButton(label: 'Submit ticket', isLoading: _submitting, onPressed: _submit),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_messageController.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      final ticket = await ref.read(supportRepositoryProvider).createTicket(
            titleId: _selectedTitleId,
            title: _selectedTitle,
            message: _messageController.text.trim(),
          );
      ref.invalidate(myTicketsProvider);
      if (mounted) {
        context.pushReplacement('/taxi/support/tickets/${ticket.ticketCode}');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not submit ticket. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
