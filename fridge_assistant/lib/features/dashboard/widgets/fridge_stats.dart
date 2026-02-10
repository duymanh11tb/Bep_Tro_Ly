import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class FridgeCategory {
  final String name;
  final IconData icon;
  final int count;
  final Color color;

  const FridgeCategory({
    required this.name,
    required this.icon,
    required this.count,
    required this.color,
  });
}

class FridgeStats extends StatelessWidget {
  final List<FridgeCategory> categories;

  const FridgeStats({
    super.key,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Thống kê tủ lạnh',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _buildCategoryCard(categories[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(FridgeCategory category) {
    // Calculate opacity colors
    final bgColor = Color.fromRGBO(
      category.color.r.toInt(),
      category.color.g.toInt(),
      category.color.b.toInt(),
      0.1,
    );
    final borderColor = Color.fromRGBO(
      category.color.r.toInt(),
      category.color.g.toInt(),
      category.color.b.toInt(),
      0.3,
    );
    final iconBgColor = Color.fromRGBO(
      category.color.r.toInt(),
      category.color.g.toInt(),
      category.color.b.toInt(),
      0.2,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              category.icon,
              color: category.color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                category.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: category.color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${category.count} món',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
