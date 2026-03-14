import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/pantry_service.dart';
import 'account_info_screen.dart';
import 'change_password_screen.dart';
import 'food_preferences_screen.dart';
import 'diet_level_screen.dart';
import 'activity_log_screen.dart';
import 'language_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String userName;
  final String? avatarUrl;

  const SettingsScreen({
    super.key,
    required this.userName,
    this.avatarUrl,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifyExpiring = true;
  bool _notifySuggest = false;

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Đăng xuất',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất không?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final authService = AuthService();
      await authService.logout();
      await PantryService.clearCache();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        _buildHeader(),
        // Body
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const SizedBox(height: 16),
              _buildSectionLabel('TÀI KHOẢN'),
              _buildSettingItem(
                icon: Icons.person_outline,
                label: 'Thông tin tài khoản',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AccountInfoScreen(
                      userName: widget.userName,
                      avatarUrl: widget.avatarUrl,
                    ),
                  ),
                ),
              ),
              _buildSettingItem(
                icon: Icons.lock_outline,
                label: 'Đổi mật khẩu',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                ),
              ),

              const SizedBox(height: 8),
              _buildSectionLabel('SỞ THÍCH VÀ TUỲ CHỈNH'),
              _buildSettingItem(
                icon: Icons.close,
                iconIsX: true,
                label: 'Sở thích ăn uống',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FoodPreferencesScreen()),
                ),
              ),
              _buildSettingItem(
                icon: Icons.bar_chart,
                label: 'Mức độ ăn uống',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DietLevelScreen()),
                ),
              ),

              const SizedBox(height: 8),
              _buildSectionLabel('THÔNG BÁO'),
              _buildToggleItem(
                icon: Icons.hourglass_empty,
                label: 'Nguyên liệu sắp hết hạn',
                value: _notifyExpiring,
                onChanged: (val) => setState(() => _notifyExpiring = val),
              ),
              _buildToggleItem(
                icon: Icons.lightbulb_outline,
                label: 'Gợi ý công thức',
                value: _notifySuggest,
                onChanged: (val) => setState(() => _notifySuggest = val),
              ),
              _buildSettingItem(
                icon: Icons.history,
                label: 'Nhật ký hoạt động',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ActivityLogScreen()),
                ),
              ),

              const SizedBox(height: 8),
              _buildSectionLabel('ỨNG DỤNG'),
              _buildSettingItem(
                icon: Icons.help_outline,
                label: 'Trợ giúp và phản hồi',
                onTap: () => _showHelpDialog(context),
              ),
              _buildSettingItem(
                icon: Icons.language,
                label: 'Ngôn ngữ',
                trailing: const Text(
                  'Tiếng Việt',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LanguageScreen()),
                ),
              ),

              const SizedBox(height: 24),
              // Logout button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: OutlinedButton.icon(
                  onPressed: () => _handleLogout(context),
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text('Đăng xuất'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Bếp Trợ Lý v1.0.0',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 8),
          Text(
            'Cài đặt',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textHint,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    bool iconIsX = false,
    required String label,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              _buildIconBox(icon, isX: iconIsX),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              trailing ?? const SizedBox.shrink(),
              if (trailing != null) const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            _buildIconBox(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBox(IconData icon, {bool isX = false}) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: isX
          ? const Icon(Icons.close, color: AppColors.primary, size: 22)
          : Icon(icon, color: AppColors.primary, size: 20),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Trợ giúp & Phản hồi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildHelpItem(Icons.email_outlined, 'Email hỗ trợ', 'support@beptrol.ly'),
            _buildHelpItem(Icons.bug_report_outlined, 'Báo cáo lỗi', 'Gửi báo cáo về sự cố'),
            _buildHelpItem(Icons.star_outline, 'Đánh giá ứng dụng', 'Xem trên cửa hàng'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
