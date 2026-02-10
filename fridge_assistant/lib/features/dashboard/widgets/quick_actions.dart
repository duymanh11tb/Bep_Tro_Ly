import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class QuickActions extends StatelessWidget {
  final VoidCallback? onScanTap;
  final VoidCallback? onAddTap;
  final VoidCallback? onSearchTap;

  const QuickActions({
    super.key,
    this.onScanTap,
    this.onAddTap,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildActionButton(
            icon: Icons.qr_code_scanner,
            label: 'Quét HD',
            onTap: onScanTap,
          ),
          const SizedBox(width: 16),
          _buildActionButton(
            icon: Icons.add,
            label: 'Thêm món',
            onTap: onAddTap,
          ),
          const SizedBox(width: 16),
          _buildActionButton(
            icon: Icons.search,
            label: 'Tìm kiếm',
            onTap: onSearchTap,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: AppColors.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
