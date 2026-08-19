import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/core/utils/taxi_formatters.dart';
import 'package:superapp_user/design_system/components/ride/custom_app_bar.dart';
import 'package:superapp_user/modules/taxi/support/application/support_providers.dart';

class TicketDetailScreen extends ConsumerStatefulWidget {
  final String ticketCode;
  const TicketDetailScreen({super.key, required this.ticketCode});

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final _replyController = TextEditingController();
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final ticketAsync = ref.watch(ticketDetailProvider(widget.ticketCode));

    return Scaffold(
      appBar: CustomAppBar(title: widget.ticketCode),
      body: ticketAsync.when(
        data: (ticket) => Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: TaxiColors.primary.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ticket.title, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text('Opened ${Formatters.date(ticket.createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Chip(label: Text(ticket.status), visualDensity: VisualDensity.compact),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: ticket.messages.length,
                itemBuilder: (context, index) {
                  final message = ticket.messages[index];
                  final isUser = message.senderRole == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                      decoration: BoxDecoration(
                        color: isUser ? TaxiColors.primary : TaxiColors.lightBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isUser)
                            Text(
                              message.senderName.isNotEmpty ? message.senderName : 'Support',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          Text(
                            message.message,
                            style: TextStyle(color: isUser ? Colors.white : TaxiColors.lightTextPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Formatters.time(message.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: isUser ? Colors.white70 : TaxiColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (ticket.status != 'closed')
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          decoration: InputDecoration(
                            hintText: 'Type a reply…',
                            filled: true,
                            fillColor: TaxiColors.lightBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: TaxiColors.primary,
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: _sending
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send_rounded, color: Colors.white),
                          onPressed: _sending ? null : _reply,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load this ticket')),
      ),
    );
  }

  Future<void> _reply() async {
    if (_replyController.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(supportRepositoryProvider).replyToTicket(widget.ticketCode, _replyController.text.trim());
      _replyController.clear();
      ref.invalidate(ticketDetailProvider(widget.ticketCode));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send reply')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
