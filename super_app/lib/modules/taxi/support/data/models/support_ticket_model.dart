class SupportTitleModel {
  final String id;
  final String title;
  final String supportType;

  const SupportTitleModel({required this.id, required this.title, required this.supportType});

  factory SupportTitleModel.fromJson(Map<String, dynamic> json) {
    return SupportTitleModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      supportType: (json['supportType'] ?? 'general').toString(),
    );
  }
}

class SupportMessageModel {
  final String id;
  final String senderRole;
  final String senderName;
  final String message;
  final DateTime createdAt;

  const SupportMessageModel({
    required this.id,
    required this.senderRole,
    required this.senderName,
    required this.message,
    required this.createdAt,
  });

  factory SupportMessageModel.fromJson(Map<String, dynamic> json) {
    return SupportMessageModel(
      id: (json['id'] ?? '').toString(),
      senderRole: (json['senderRole'] ?? '').toString(),
      senderName: (json['senderName'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
    );
  }
}

class SupportTicketModel {
  final String id;
  final String ticketCode;
  final String title;
  final String supportType;
  final String status;
  final List<SupportMessageModel> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupportTicketModel({
    required this.id,
    required this.ticketCode,
    required this.title,
    required this.supportType,
    required this.status,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketModel(
      id: (json['id'] ?? '').toString(),
      ticketCode: (json['ticketCode'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      supportType: (json['supportType'] ?? 'general').toString(),
      status: (json['status'] ?? 'pending').toString(),
      messages: (json['messages'] as List? ?? [])
          .map((e) => SupportMessageModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}') ?? DateTime.now(),
    );
  }
}
