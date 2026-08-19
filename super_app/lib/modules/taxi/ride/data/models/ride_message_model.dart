class RideMessageModel {
  final String id;
  final String senderRole;
  final String senderId;
  final String message;
  final DateTime sentAt;

  const RideMessageModel({
    required this.id,
    required this.senderRole,
    required this.senderId,
    required this.message,
    required this.sentAt,
  });

  factory RideMessageModel.fromJson(Map<String, dynamic> json) {
    return RideMessageModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      senderRole: (json['senderRole'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      sentAt: DateTime.tryParse('${json['sentAt']}') ?? DateTime.now(),
    );
  }
}
