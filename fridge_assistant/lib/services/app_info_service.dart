class AppInfoService {
  static const String appName = 'Bếp Trợ Lý';
  static const String version = '1.0.0+1';
  static const String shortDescription =
      'Trợ lý bếp thông minh giúp quản lý tủ lạnh, gợi ý công thức và lập lịch bữa ăn.';

  static String get versionLabel => 'Phiên bản $version';

  static String formatMemberSince(String? createdAt) {
    if (createdAt == null || createdAt.trim().isEmpty) {
      return 'gần đây';
    }

    try {
      final parsed = DateTime.parse(createdAt).toLocal();
      return '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
    } catch (_) {
      return createdAt;
    }
  }
}
