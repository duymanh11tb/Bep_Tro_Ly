class ChatMessageModel {
  final int messageId;
  final int fridgeId;
  final int userId;
  final String displayName;
  final String? photoUrl;
  final String content;
  final DateTime createdAt;

  ChatMessageModel({
    required this.messageId,
    required this.fridgeId,
    required this.userId,
    required this.displayName,
    this.photoUrl,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      messageId: json['message_id'] ?? 0,
      fridgeId: json['fridge_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      displayName: json['display_name'] ?? 'Unknown',
      photoUrl: json['photo_url'],
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null 
          ? (json['created_at'] is String 
              ? DateTime.parse(json['created_at']) 
              : DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'fridge_id': fridgeId,
      'user_id': userId,
      'display_name': displayName,
      'photo_url': photoUrl,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
