class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    this.orderId,
    required this.senderRole,
    required this.senderId,
    required this.recipientRole,
    this.recipientId,
    required this.text,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String? orderId;
  final String senderRole;
  final String senderId;
  final String recipientRole;
  final String? recipientId;
  final String text;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isFromDeliveryPartner => senderRole == 'DELIVERY_PARTNER';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? '').toString(),
      orderId: json['orderId']?.toString(),
      senderRole: json['senderRole'] as String? ?? '',
      senderId: (json['senderId'] ?? '').toString(),
      recipientRole: json['recipientRole'] as String? ?? '',
      recipientId: json['recipientId']?.toString(),
      text: json['text'] as String? ?? '',
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ChatHistoryPage {
  const ChatHistoryPage({
    required this.messages,
    required this.page,
    required this.totalPages,
  });

  final List<ChatMessage> messages;
  final int page;
  final int totalPages;
}
