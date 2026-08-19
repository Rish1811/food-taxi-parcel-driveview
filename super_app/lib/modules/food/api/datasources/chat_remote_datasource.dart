import 'package:superapp_user/core/config/api_config.dart';
import 'package:superapp_user/core/network/api_client.dart';
import 'package:superapp_user/modules/food/data/models/chat_model.dart';

/// `/food/chat` — conversations with the delivery partner (or admin support)
/// on an active order. Real-time delivery is the shared [SocketService];
/// this datasource is the REST seed + fallback.
class ChatRemoteDataSource {
  final ApiClient _client;

  const ChatRemoteDataSource(this._client);

  /// `GET /food/chat/conversations`, optionally narrowed to one order.
  ///
  /// The server sorts newest first and only returns threads this user takes part
  /// in, so there is nothing to filter or re-order client-side.
  Future<List<ChatConversation>> getConversations({String? orderId}) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.chatConversations,
      query: {if (orderId != null && orderId.isNotEmpty) 'orderId': orderId},
    );
    return ((data['conversations'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ChatConversation.fromApi(e.cast<String, dynamic>()))
        .toList();
  }

  /// Calling this auto-marks incoming messages as read server-side.
  Future<({List<ChatMessage> messages, int totalPages})> getMessages({
    required String conversationId,
    int page = 1,
    int limit = 30,
  }) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.chatMessages,
      query: {'conversationId': conversationId, 'page': page, 'limit': limit},
    );
    final messages = ((data['messages'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ChatMessage.fromApi(e.cast<String, dynamic>()))
        .toList();
    final pagination = (data['pagination'] as Map?)?.cast<String, dynamic>() ?? const {};
    return (messages: messages, totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1);
  }

  /// `peerRole: ADMIN` omits [peerId]/[orderId] (support chat); any other
  /// peer role requires both.
  Future<ChatMessage> sendMessage({
    required String peerRole,
    String? peerId,
    String? orderId,
    required String text,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiPaths.chatMessages,
      body: {
        'peerRole': peerRole,
        if (peerId != null) 'peerId': peerId,
        if (orderId != null) 'orderId': orderId,
        'text': text,
      },
    );
    final message = data['message'];
    return ChatMessage.fromApi(message is Map ? message.cast<String, dynamic>() : data);
  }

  Future<int> markRead(String conversationId) async {
    final data = await _client.patch<Map<String, dynamic>>(ApiPaths.chatConversationRead(conversationId));
    return (data['updated'] as num?)?.toInt() ?? 0;
  }
}
