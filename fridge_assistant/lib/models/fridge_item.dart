/// Model cho nguyên liệu trong tủ lạnh
class FridgeItem {
  final String id;
  final String name;
  final String? imageUrl;
  final double quantity;
  final String unit;
  final DateTime expiryDate;
  final String category;
  final DateTime addedDate;

  FridgeItem({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.quantity,
    required this.unit,
    required this.expiryDate,
    required this.category,
    required this.addedDate,
  });

  /// Số ngày còn lại trước khi hết hạn
  int get daysUntilExpiry {
    return expiryDate.difference(DateTime.now()).inDays;
  }

  /// Kiểm tra đã hết hạn chưa
  bool get isExpired => daysUntilExpiry < 0;

  /// Kiểm tra sắp hết hạn (trong 3 ngày)
  bool get isExpiringSoon => daysUntilExpiry >= 0 && daysUntilExpiry <= 3;

  /// Text hiển thị thời gian hết hạn
  String get expiryText {
    if (isExpired) {
      return 'Đã hết hạn';
    } else if (daysUntilExpiry == 0) {
      return 'Hết hạn hôm nay';
    } else if (daysUntilExpiry == 1) {
      return 'Hết hạn : mai';
    } else {
      return 'Hết hạn : $daysUntilExpiry ngày';
    }
  }

  factory FridgeItem.fromJson(Map<String, dynamic> json) {
    return FridgeItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      imageUrl: json['image_url'],
      quantity: (json['quantity'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      expiryDate: DateTime.parse(json['expiry_date']),
      category: json['category'] ?? '',
      addedDate: DateTime.parse(json['added_date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'quantity': quantity,
      'unit': unit,
      'expiry_date': expiryDate.toIso8601String(),
      'category': category,
      'added_date': addedDate.toIso8601String(),
    };
  }
}
