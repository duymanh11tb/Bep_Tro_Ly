import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class DietLevelScreen extends StatefulWidget {
  const DietLevelScreen({super.key});

  @override
  State<DietLevelScreen> createState() => _DietLevelScreenState();
}

class _DietLevelScreenState extends State<DietLevelScreen> {
  int _selectedLevel = 1; // 0: nhẹ, 1: trung bình, 2: cao

  final List<_DietLevel> _levels = const [
    _DietLevel(
      index: 0,
      title: 'Ăn nhẹ',
      subtitle: '1–2 bữa/ngày, khẩu phần nhỏ',
      icon: Icons.sentiment_satisfied_alt_outlined,
      color: Color(0xFF4DB6AC),
    ),
    _DietLevel(
      index: 1,
      title: 'Bình thường',
      subtitle: '3 bữa/ngày, khẩu phần vừa',
      icon: Icons.sentiment_neutral_outlined,
      color: Color(0xFF4CAF50),
    ),
    _DietLevel(
      index: 2,
      title: 'Ăn nhiều',
      subtitle: '3+ bữa/ngày, khẩu phần lớn',
      icon: Icons.sports_martial_arts_outlined,
      color: Color(0xFFFF8F00),
    ),
  ];

  int _mealsPerDay = 3;
  bool _eatSnacks = false;
  bool _countCalories = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Mức độ ăn uống',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chế độ ăn',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_levels.length, (i) => _buildLevelCard(_levels[i])),
            const SizedBox(height: 24),
            const Text(
              'Số bữa mỗi ngày',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCountBtn(
                        Icons.remove,
                        () => setState(() {
                          if (_mealsPerDay > 1) _mealsPerDay--;
                        }),
                      ),
                      const SizedBox(width: 28),
                      Text(
                        '$_mealsPerDay',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 28),
                      _buildCountBtn(
                        Icons.add,
                        () => setState(() {
                          if (_mealsPerDay < 8) _mealsPerDay++;
                        }),
                      ),
                    ],
                  ),
                  const Text(
                    'bữa / ngày',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tuỳ chọn thêm',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            _buildOptionTile(
              icon: Icons.cookie_outlined,
              title: 'Ăn vặt giữa các bữa',
              value: _eatSnacks,
              onChanged: (v) => setState(() => _eatSnacks = v),
            ),
            _buildOptionTile(
              icon: Icons.calculate_outlined,
              title: 'Đếm lượng calo',
              value: _countCalories,
              onChanged: (v) => setState(() => _countCalories = v),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Lưu cài đặt',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(_DietLevel level) {
    final isSelected = _selectedLevel == level.index;
    return GestureDetector(
      onTap: () => setState(() => _selectedLevel = level.index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? level.color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? level.color : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: level.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(level.icon, color: level.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? level.color : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    level.subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: level.color, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildCountBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ),
    );
  }

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Đã lưu mức độ ăn uống'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }
}

class _DietLevel {
  final int index;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _DietLevel({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
