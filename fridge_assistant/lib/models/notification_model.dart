class NotificationModel {
  final int notificationId;
  final String type;
  final String title;
  final String body;
  final int? relatedItemId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.notificationId,
    required this.type,
    required this.title,
    required this.body,
    this.relatedItemId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationId: json['notification_id'] ?? 0,
      type: json['type'] ?? 'system',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      relatedItemId: json['related_item_id'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}
