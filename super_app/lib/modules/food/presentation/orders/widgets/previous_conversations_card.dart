import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/modules/food/data/models/chat_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/shared/support/presentation/chat/screens/chat_screen.dart';
import 'package:superapp_user/app/routing/route_names.dart';
import 'package:superapp_user/modules/food/presentation/orders/viewmodels/order_conversations_viewmodel.dart';

/// Previous support threads for this order.
class PreviousConversationsCard extends ConsumerWidget {
  const PreviousConversationsCard({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(orderConversationsProvider(orderId));
    final items = conversations.asData?.value ?? const <ChatConversation>[];
    if (items.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final dividerColor = isDark ? AppColors.borderDark : AppColors.dividerLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'ALL CONVERSATION THREADS',
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),

        // Threads Card Container
        Container(
          width: double.infinity,
          color: cardBg,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(color: dividerColor, height: 1, thickness: 1),
                _ConversationRow(
                  conversation: items[i],
                  orderId: orderId,
                  textColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.orderId,
    required this.textColor,
    required this.secondaryColor,
  });

  final ChatConversation conversation;
  final String orderId;
  final Color textColor;
  final Color secondaryColor;

  static final _stamp = DateFormat('MMMM d, h:mm a');

  String get _title {
    if (conversation.title.isNotEmpty) return conversation.title;
    return conversation.peerRole == 'ADMIN'
        ? 'Support conversation'
        : 'Chat with delivery partner';
  }

  void _open(BuildContext context) {
    Haptics.light();
    context.push(
      RouteNames.chat,
      extra: ChatArgs(
        orderId: conversation.orderId ?? orderId,
        peerId: conversation.peerId,
        peerName: conversation.peerRole == 'ADMIN' ? 'Support' : 'Delivery Partner',
        peerRole: conversation.peerRole.isEmpty ? 'ADMIN' : conversation.peerRole,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final created = conversation.createdAt;
    final orderNum = conversation.orderId ?? orderId;
    final dateFormatted = created != null ? _stamp.format(created.toLocal()) : '';

    final subtitle = 'Order #${orderNum.length > 15 ? orderNum.substring(orderNum.length - 15) : orderNum}${dateFormatted.isNotEmpty ? ' · $dateFormatted' : ''}';

    return InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: secondaryColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: secondaryColor.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
