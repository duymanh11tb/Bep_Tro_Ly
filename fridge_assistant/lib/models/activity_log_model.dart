import 'dart:convert';

class ActivityLogModel {
  final int logId;
  final int userId;
  final String userName;
  final String? userPhoto;
  final String activityType;
  final Map<String, dynamic> extraData;
  final DateTime createdAt;

  ActivityLogModel({
    required this.logId,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.activityType,
    required this.extraData,
    required this.createdAt,
  });

  factory ActivityLogModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> extra = {};
    if (json['extra_data'] != null) {
      if (json['extra_data'] is String) {
        extra = jsonDecode(json['extra_data']);
      } else {
        extra = json['extra_data'];
      }
    }

    return ActivityLogModel(
      logId: json['log_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      userName: json['user_name'] ?? 'Người dùng',
      userPhoto: json['user_photo'],
      activityType: json['activity_type'] ?? '',
      extraData: extra,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  String get displayMessage {
    final itemName = extraData['itemName'] ?? 'Nguyên liệu';
    final quantity = extraData['quantity'] ?? '';
    final unit = extraData['unit'] ?? '';

    switch (activityType) {
      case 'add_item':
        return 'Đã thêm $quantity $unit $itemName';
      case 'use_item':
        return 'Đã lấy $quantity $unit $itemName';
      case 'discard_item':
        return 'Đã bỏ $quantity $unit $itemName';
      case 'cook_recipe':
        return 'Đã nấu $itemName';
      default:
        return 'Hoạt động tủ lạnh';
    }
  }

  String get activityLabel {
    switch (activityType) {
      case 'add_item':
        return 'Thêm vào';
      case 'use_item':
        return 'Lấy ra';
      case 'discard_item':
        return 'Loại bỏ';
      case 'cook_recipe':
        return 'Nấu ăn';
      default:
        return 'Khác';
    }
  }
}
