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
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.qr_code_scanner,
            label: 'Quét HD',
            onTap: onScanTap,
          ),
          const SizedBox(width: 20),
          _buildActionButton(
            icon: Icons.add_circle_outline,
            label: 'Thêm món',
            onTap: onAddTap,
          ),
          const SizedBox(width: 20),
          _buildActionButton(
            icon: Icons.search_rounded,
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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.inputBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(0, 0, 0, 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
