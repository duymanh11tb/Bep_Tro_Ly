import 'package:fridge_assistant/core/localization/app_material.dart';
import '../../core/localization/app_locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../services/app_info_service.dart';
import '../../services/app_preferences_service.dart';
import '../../services/auth_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/pantry_service.dart';
import '../../services/support_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool isTab;
  const SettingsScreen({super.key, this.isTab = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  bool _expiryNotification = true;
  bool _dailyRecipeNotification = false;
  String _languageCode = AppPreferencesService.vietnamese;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final showExpired = await PantryService.getShowExpiredPreference();
    final showRecipeSuggestions =
        await PantryService.getShowRecipeSuggestionsPreference();
    final languageCode = await AppPreferencesService.getPreferredLanguageCode();
    if (mounted) {
      setState(() {
        _expiryNotification = showExpired;
        _dailyRecipeNotification = showRecipeSuggestions;
        _languageCode = languageCode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: widget.isTab
          ? null
          : AppBar(
              title: const Text(
                'Cài đặt',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isTab) ...[
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Text(
                  'Cài đặt',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            _buildSectionHeader('TÀI KHOẢN'),
            _buildSettingsGroup([
              _buildSettingsItem(
                icon: Icons.person_outline,
                title: 'Thông tin cá nhân',
                onTap: () {
                  Navigator.pushNamed(context, '/profile');
                },
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsItem(
                icon: Icons.lock_outline,
                title: 'Đổi mật khẩu',
                onTap: () {
                  Navigator.pushNamed(context, '/change-password');
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('SỞ THÍCH & TÙY CHỈNH'),
            _buildSettingsGroup([
              _buildSettingsItem(
                icon: Icons.restaurant_menu,
                title: 'Sở thích ăn uống',
                onTap: () {
                  Navigator.pushNamed(context, '/eating-preferences');
                },
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsItem(
                icon: Icons.signal_cellular_alt,
                title: 'Mức độ nấu ăn',
                onTap: () {
                  Navigator.pushNamed(context, '/cooking-level');
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('THÔNG BÁO'),
            _buildSettingsGroup([
              _buildSwitchItem(
                icon: Icons.hourglass_empty,
                title: 'Hiện SP đã hết hạn',
                subtitle: 'Hiển thị nguyên liệu đã hết hạn trên trang chủ',
                value: _expiryNotification,
                onChanged: (val) {
                  debugPrint('[Settings] setShowExpiredPreference: $val');
                  setState(() => _expiryNotification = val);
                  PantryService.setShowExpiredPreference(val);
                },
              ),
              const Divider(height: 1, indent: 56),
              _buildSwitchItem(
                icon: Icons.lightbulb_outline,
                title: 'Gợi ý công thức hàng ngày',
                subtitle:
                    'Hiển thị các công thức gợi ý trên trang chủ từ nguồn recipe',
                value: _dailyRecipeNotification,
                onChanged: (val) {
                  debugPrint(
                    '[Settings] setShowRecipeSuggestionsPreference: $val',
                  );
                  setState(() => _dailyRecipeNotification = val);
                  PantryService.setShowRecipeSuggestionsPreference(val);
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('ỨNG DỤNG'),
            _buildSettingsGroup([
              _buildSettingsItem(
                icon: Icons.language,
                title: 'Ngôn ngữ',
                trailingText: AppPreferencesService.labelFor(_languageCode),
                onTap: _handleLanguageSelection,
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsItem(
                icon: Icons.help_outline,
                title: 'Trợ giúp & Phản hồi',
                onTap: () {
                  Navigator.pushNamed(context, '/help-feedback');
                },
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsItem(
                icon: Icons.info_outline,
                title: 'Về Bếp Trợ Lý',
                trailingText: AppInfoService.version,
                onTap: _showAboutApp,
              ),
            ]),
            const SizedBox(height: 32),
            _buildLogoutButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary.withValues(alpha: 0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: trailingText == null
          ? const Icon(Icons.chevron_right, color: AppColors.textHint)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailingText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            )
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: _handleLogout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, color: AppColors.error),
            const SizedBox(width: 8),
            Text(
              'Đăng xuất',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final googleAuthService = GoogleAuthService();
      await googleAuthService.signOut();
      await _authService.logout();
      await PantryService.clearCache();
      
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/onboarding', 
          (route) => false,
          arguments: {'showLogoutNotice': true},
        );
      }
    }
  }

  Future<void> _handleLanguageSelection() async {
    final selectedCode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn ngôn ngữ ưu tiên',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tuỳ chọn này sẽ được dùng cho trải nghiệm cá nhân hoá và các cập nhật giao diện sau này.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ...AppPreferencesService.supportedLanguages.map((option) {
                  return RadioListTile<String>(
                    value: option.code,
                    groupValue: _languageCode,
                    activeColor: AppColors.primary,
                    title: Text(option.label),
                    subtitle: Text(option.subtitle),
                    onChanged: (value) => Navigator.of(context).pop(value),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selectedCode == null || selectedCode == _languageCode) return;

    await AppLocaleController.instance.setLocaleCode(selectedCode);
    if (!mounted) return;

    setState(() => _languageCode = selectedCode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã lưu ngôn ngữ ưu tiên: ${AppPreferencesService.labelFor(selectedCode)}',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showAboutApp() {
    showAboutDialog(
      context: context,
      applicationName: context.tr(AppInfoService.appName),
      applicationVersion: context.tr(AppInfoService.versionLabel),
      applicationIcon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.kitchen_rounded, color: AppColors.primary),
      ),
      children: const [
        SizedBox(height: 12),
        Text(AppInfoService.shortDescription),
        SizedBox(height: 12),
        Text('Email hỗ trợ: ${SupportService.supportEmail}'),
        SizedBox(height: 4),
        Text('Hotline: ${SupportService.supportPhone}'),
      ],
    );
  }
}
