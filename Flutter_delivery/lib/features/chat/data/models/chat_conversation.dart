class ChatConversation {
  const ChatConversation({
    required this.conversationId,
    this.orderId,
    required this.peerRole,
    this.peerId,
    this.lastMessage,
    this.lastAt,
    required this.unread,
  });

  final String conversationId;
  final String? orderId;
  final String peerRole;
  final String? peerId;
  final String? lastMessage;
  final DateTime? lastAt;
  final int unread;

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final peerToken = json['peerToken'] as String? ?? '';
    final parts = peerToken.split(':');
    final peerRole = parts.isNotEmpty ? parts.first : '';
    final peerId = parts.length > 1 ? parts.sublist(1).join(':') : null;

    return ChatConversation(
      conversationId: (json['conversationId'] ?? '').toString(),
      orderId: json['orderId']?.toString(),
      peerRole: peerRole,
      peerId: peerId,
      lastMessage: json['lastMessage'] as String?,
      lastAt: json['lastAt'] != null
          ? DateTime.tryParse(json['lastAt'].toString())
          : null,
      unread: (json['unread'] as num?)?.toInt() ?? 0,
    );
  }
}
