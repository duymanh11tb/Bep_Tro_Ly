import 'package:fridge_assistant/core/localization/app_material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/fridge_item.dart';

class ExpiringItems extends StatelessWidget {
  final List<FridgeItem> items;
  final VoidCallback? onViewAllTap;

  const ExpiringItems({
    super.key,
    required this.items,
    this.onViewAllTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Sắp hết hạn',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onViewAllTap,
                child: const Text(
                  'Xem tất cả',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Items list
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _buildExpiringItem(items[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpiringItem(FridgeItem item) {
    final daysLeft = item.expiryDate.difference(DateTime.now()).inDays;
    String expiryLabel;
    Color expiryColor;

    if (item.isExpired) {
      expiryLabel = 'Đã hết hạn';
      expiryColor = AppColors.error;
    } else if (daysLeft == 0) {
      expiryLabel = 'Hết hạn: hôm nay';
      expiryColor = AppColors.error;
    } else if (daysLeft == 1) {
      expiryLabel = 'Hết hạn: mai';
      expiryColor = AppColors.warning;
    } else {
      expiryLabel = 'Hết hạn: $daysLeft ngày';
      expiryColor = AppColors.textSecondary;
    }

    return Container(
      width: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image area
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: 85,
              width: double.infinity,
              color: AppColors.backgroundSecondary,
              child: item.imageUrl != null
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderImage(item),
                    )
                  : _buildPlaceholderImage(item),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  expiryLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: expiryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage(FridgeItem item) {
    // Choose icon based on category
    IconData icon;
    Color iconColor;
    switch (item.category.toLowerCase()) {
      case 'sữa':
        icon = Icons.egg_outlined;
        iconColor = Colors.orange;
        break;
      case 'rau củ':
        icon = Icons.eco;
        iconColor = Colors.green;
        break;
      case 'thịt & cá':
        icon = Icons.set_meal;
        iconColor = Colors.red;
        break;
      default:
        icon = Icons.kitchen_outlined;
        iconColor = AppColors.textHint;
    }
    return Center(
      child: Icon(icon, color: iconColor, size: 36),
    );
  }
}
