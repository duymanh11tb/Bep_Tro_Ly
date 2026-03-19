import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ProfileStats extends StatelessWidget {
  final int cookedCount;
  final String savings;
  final String optimizationRate;

  const ProfileStats({
    super.key,
    required this.cookedCount,
    required this.savings,
    required this.optimizationRate,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard(
            context,
            cookedCount.toString(),
            'Món đã nấu',
            Icons.restaurant,
            const Color(0xFFE8F5E9),
            const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            context,
            savings,
            'Tiết kiệm',
            Icons.savings,
            const Color(0xFFE8F5E9),
            const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            context,
            optimizationRate,
            'Tỉ lệ sạch tủ',
            Icons.recycling,
            const Color(0xFFE8F5E9),
            const Color(0xFF2E7D32),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    Color bgColor,
    Color iconColor,
  ) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
