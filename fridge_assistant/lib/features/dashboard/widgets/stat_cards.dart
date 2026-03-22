import 'package:fridge_assistant/core/localization/app_material.dart';
import '../../../core/theme/app_colors.dart';

class StatCards extends StatelessWidget {
  final int recipesAvailable;
  final int moneySaved;

  const StatCards({
    super.key,
    required this.recipesAvailable,
    required this.moneySaved,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Card: Có thể nấu
          Expanded(
            child: _buildStatCard(
              icon: Icons.restaurant_menu,
              title: 'Có thể nấu',
              value: recipesAvailable.toString(),
              subtitle: 'Món ăn từ nguyên liệu\ncó sẵn!',
              accentColor: AppColors.primary,
              backgroundColor: Colors.white,
              trailing: const Icon(
                Icons.arrow_forward,
                color: AppColors.primary,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Card: Đã tiết kiệm
          Expanded(
            child: _buildStatCard(
              icon: Icons.savings_outlined,
              title: 'Đã tiết kiệm',
              value: '${moneySaved}k đ',
              subtitle: 'Tháng này bạn làm\nrất tốt !',
              accentColor: AppColors.primary,
              backgroundColor: AppColors.primaryLight,
              bottomLine: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color accentColor,
    required Color backgroundColor,
    Widget? trailing,
    bool bottomLine = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          // Value
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: accentColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          // Subtitle
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          // Bottom accent line for savings card
          if (bottomLine) ...[
            const SizedBox(height: 10),
            Container(
              height: 3,
              width: 40,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
