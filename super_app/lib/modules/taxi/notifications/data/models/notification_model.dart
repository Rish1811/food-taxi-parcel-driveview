class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.data = const {},
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? 'Notification').toString(),
      body: (json['body'] ?? json['message'] ?? '').toString(),
      type: (json['type'] ?? 'general').toString(),
      isRead: json['isRead'] == true || json['read'] == true,
      createdAt: DateTime.tryParse('${json['createdAt'] ?? json['created_at'] ?? ''}') ?? DateTime.now(),
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : {},
    );
  }
}
