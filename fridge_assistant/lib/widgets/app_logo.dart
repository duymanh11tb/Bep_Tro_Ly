import 'package:fridge_assistant/core/localization/app_material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Logo component hiển thị icon và tên ứng dụng "Bếp Trợ Lý"
class AppLogo extends StatelessWidget {
  final bool showTagline;
  final double iconSize;
  final MainAxisAlignment alignment;

  const AppLogo({
    super.key,
    this.showTagline = true,
    this.iconSize = 56,
    this.alignment = MainAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo Icon - Fridge icon with green background
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.kitchen_rounded,
            color: Colors.white,
            size: iconSize * 0.6,
          ),
        ),
        const SizedBox(height: 12),
        // App Name
        Text(
          'Bếp Trợ Lý',
          style: AppTextStyles.appTitle,
          textAlign: TextAlign.center,
        ),
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            'Sống xanh, nấu ăn ngon lành',
            style: AppTextStyles.appTagline,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
