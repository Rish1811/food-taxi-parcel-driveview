import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/modules/food/data/models/chat_model.dart';
import 'package:superapp_user/shared/support/application/chat_providers.dart';

/// Previous support threads for one order.
///
/// Family-keyed by order id so each Order Details screen holds its own list and
/// two orders open in a back stack cannot overwrite each other's state.
///
/// Returns an empty list rather than an error when the fetch fails: this is a
/// supplementary section, and a support outage should not put an error box on an
/// otherwise healthy order screen. The section simply stays hidden.
final orderConversationsProvider =
    FutureProvider.family<List<ChatConversation>, String>((ref, orderId) async {
  if (orderId.isEmpty) return const [];
  try {
    return await ref
        .read(chatRemoteDataSourceProvider)
        .getConversations(orderId: orderId);
  } catch (_) {
    return const [];
  }
});
