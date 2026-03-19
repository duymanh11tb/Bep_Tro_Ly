import 'package:flutter_dotenv/flutter_dotenv.dart';

class FridgeMemberModel {
  final int userId;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String role;
  final String status;
  final DateTime invitedAt;
  final DateTime? joinedAt;

  FridgeMemberModel({
    required this.userId,
    required this.displayName,
    required this.email,
    this.photoUrl,
    required this.role,
    required this.status,
    required this.invitedAt,
    this.joinedAt,
  });

  factory FridgeMemberModel.fromJson(Map<String, dynamic> json) {
    String? photoUrl = json['photo_url'];
    if (photoUrl != null && photoUrl.startsWith('/')) {
      photoUrl = '${dotenv.env['API_URL']}$photoUrl';
    }

    return FridgeMemberModel(
      userId: json['user_id'] ?? 0,
      displayName: json['display_name'] ?? '',
      email: json['email'] ?? '',
      photoUrl: photoUrl,
      role: json['role'] ?? 'member',
      status: json['status'] ?? 'pending',
      invitedAt: DateTime.parse(json['invited_at'] ?? DateTime.now().toIso8601String()),
      joinedAt: json['joined_at'] != null ? DateTime.parse(json['joined_at']) : null,
    );
  }
}

class FridgeModel {
  final int fridgeId;
  final String name;
  final String? location;
  final int ownerId;
  final String status;
  final DateTime createdAt;
  List<FridgeMemberModel> members;

  FridgeModel({
    required this.fridgeId,
    required this.name,
    this.location,
    required this.ownerId,
    required this.status,
    required this.createdAt,
    this.members = const [],
  });

  factory FridgeModel.fromJson(Map<String, dynamic> json) {
    return FridgeModel(
      fridgeId: json['fridge_id'] ?? 0,
      name: json['name'] ?? '',
      location: json['location'],
      ownerId: json['owner_id'] ?? 0,
      status: json['status'] ?? 'active',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      members: (json['members'] as List? ?? [])
          .map((m) => FridgeMemberModel.fromJson(m))
          .toList(),
    );
  }
}
