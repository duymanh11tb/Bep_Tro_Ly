import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AppSettingsSection extends StatelessWidget {
  final bool expiryNotifications;
  final bool dishSuggestions;
  final String language;
  final Function(bool) onExpiryToggle;
  final Function(bool) onSuggestionsToggle;
  final VoidCallback onLanguageTap;

  const AppSettingsSection({
    super.key,
    required this.expiryNotifications,
    required this.dishSuggestions,
    required this.language,
    required this.onExpiryToggle,
    required this.onSuggestionsToggle,
    required this.onLanguageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Cài đặt ứng dụng',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildToggleItem(
          'Thông báo hết hạn',
          'Nhắc nhở trước 2 ngày',
          Icons.notifications_active,
          Colors.blue[50]!,
          Colors.blue[600]!,
          expiryNotifications,
          onExpiryToggle,
        ),
        _buildToggleItem(
          'Gợi ý món ăn',
          'Mỗi ngày lúc 16:00',
          Icons.restaurant_menu,
          Colors.purple[50]!,
          Colors.purple[600]!,
          dishSuggestions,
          onSuggestionsToggle,
        ),
        _buildNavigationItem(
          'Ngôn ngữ',
          language,
          Icons.language,
          Colors.orange[50]!,
          Colors.orange[600]!,
          onLanguageTap,
        ),
      ],
    );
  }

  Widget _buildToggleItem(
    String title,
    String subtitle,
    IconData icon,
    Color iconBgColor,
    Color iconColor,
    bool value,
    Function(bool) onChanged,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return null;
        }),
      ),
    );
  }

  Widget _buildNavigationItem(
    String title,
    String value,
    IconData icon,
    Color iconBgColor,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
        ],
      ),
    );
  }
}
