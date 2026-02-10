import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class GreetingSection extends StatelessWidget {
  final String userName;
  final String? statusMessage;

  const GreetingSection({
    super.key,
    required this.userName,
    this.statusMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xin chào, $userName',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            statusMessage ?? 'Tủ lạnh đang cần sự chú ý của bạn',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
