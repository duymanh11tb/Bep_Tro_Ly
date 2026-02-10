import 'package:flutter/material.dart';
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
              iconColor: AppColors.primary,
              title: 'Có thể nấu',
              value: recipesAvailable.toString(),
              subtitle: 'Món ăn từ nguyên liệu\ncó sẵn!',
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          // Card: Đã tiết kiệm
          Expanded(
            child: _buildStatCard(
              icon: Icons.savings_outlined,
              iconColor: AppColors.primary,
              title: 'Đã tiết kiệm',
              value: '${moneySaved}k',
              valueSuffix: ' đ',
              subtitle: 'Tháng này bạn làm rất\ntốt !',
              backgroundColor: AppColors.primaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    String? valueSuffix,
    required String subtitle,
    required Color backgroundColor,
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
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1,
                ),
              ),
              if (valueSuffix != null)
                Text(
                  valueSuffix,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
