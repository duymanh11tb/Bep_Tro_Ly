import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class FoodPreferencesScreen extends StatefulWidget {
  const FoodPreferencesScreen({super.key});

  @override
  State<FoodPreferencesScreen> createState() => _FoodPreferencesScreenState();
}

class _FoodPreferencesScreenState extends State<FoodPreferencesScreen> {
  // ─── Chế độ ăn (chọn 1 hoặc nhiều) ───
  final List<_DietItem> _dietItems = [
    _DietItem(label: 'Bình thường', iconAsset: Icons.restaurant_outlined, isSelected: true),
    _DietItem(label: 'Ăn chay (Vegetarian)', iconAsset: Icons.eco_outlined, isSelected: false),
    _DietItem(label: 'Ăn kiêng (Eat clean)', iconAsset: Icons.spa_outlined, isSelected: false),
  ];

  // ─── Dị ứng & nguyên liệu cần tránh ───
  final List<_AllergyItem> _allergyItems = [
    _AllergyItem(label: 'Đậu phộng', icon: Icons.no_food, iconColor: const Color(0xFFE57373), isSelected: true),
    _AllergyItem(label: 'Sữa & Chế phẩm', icon: Icons.local_drink_outlined, iconColor: const Color(0xFF81C784), isSelected: false),
    _AllergyItem(label: 'Hải sản', icon: Icons.set_meal_outlined, iconColor: const Color(0xFFE57373), isSelected: true),
  ];

  // ─── Ẩm thực yêu thích (multi-select chips) ───
  final List<_CuisineItem> _cuisines = [
    _CuisineItem(label: 'Việt Nam', isSelected: true),
    _CuisineItem(label: 'Hàn Quốc', isSelected: true),
    _CuisineItem(label: 'Nhật Bản', isSelected: false),
    _CuisineItem(label: 'Trung Hoa', isSelected: false),
    _CuisineItem(label: 'Món Âu', isSelected: false),
  ];

  bool _isLoading = false;

  // Hiện dialog thêm dị ứng mới
  Future<void> _showAddAllergyDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Thêm nguyên liệu cần tránh',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'VD: Tôm, Gluten, Đậu nành...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _allergyItems.add(_AllergyItem(
          label: result,
          icon: Icons.block,
          iconColor: const Color(0xFFE57373),
          isSelected: true,
        ));
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    // TODO: Gọi API lưu lên backend
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Đã lưu sở thích ăn uống'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Sở thích ăn uống',
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
      body: Column(
        children: [
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subtitle
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Text(
                      'Chọn các chế độ ăn uống và nguyên liệu bạn muốn tránh. Bếp trợ lý sẽ gợi ý công thức phù hợp nhất cho bạn.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),

                  // ─── CHẾ ĐỘ ĂN ───
                  _buildSectionLabel('CHẾ ĐỘ ĂN'),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: List.generate(_dietItems.length, (i) {
                        final item = _dietItems[i];
                        final isLast = i == _dietItems.length - 1;
                        return _buildCheckRow(
                          icon: item.iconAsset,
                          iconColor: AppColors.primary,
                          label: item.label,
                          isSelected: item.isSelected,
                          showDivider: !isLast,
                          onTap: () => setState(() => item.isSelected = !item.isSelected),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── DỊ ỨNG VÀ NGUYÊN LIỆU CẦN TRÁNH ───
                  _buildSectionLabel('DỊ ỨNG VÀ NGUYÊN LIỆU CẦN TRÁNH'),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        ...List.generate(_allergyItems.length, (i) {
                          final item = _allergyItems[i];
                          return _buildCheckRow(
                            icon: item.icon,
                            iconColor: item.iconColor,
                            label: item.label,
                            isSelected: item.isSelected,
                            showDivider: true,
                            onTap: () => setState(() => item.isSelected = !item.isSelected),
                          );
                        }),
                        // Nút thêm nguyên liệu
                        GestureDetector(
                          onTap: _showAddAllergyDialog,
                          child: Container(
                            margin: const EdgeInsets.all(14),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.divider,
                                width: 1.5,
                                style: BorderStyle.none, // flutter doesn't support dashed natively
                              ),
                              color: const Color(0xFFFAFAFA),
                            ),
                            child: DashedBorder(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add, color: AppColors.textHint, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Thêm nguyên liệu cần tránh khác',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── ẨM THỰC YÊU THÍCH ───
                  _buildSectionLabel('ẨM THỰC YÊU THÍCH'),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _cuisines.map((c) {
                        return GestureDetector(
                          onTap: () => setState(() => c.isSelected = !c.isSelected),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: c.isSelected
                                  ? AppColors.primaryLight
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: c.isSelected
                                    ? AppColors.primary
                                    : AppColors.divider,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  c.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: c.isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                                if (c.isSelected) ...[
                                  const SizedBox(width: 5),
                                  const Icon(Icons.check,
                                      color: AppColors.primary, size: 14),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ─── Bottom button ───
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Xác nhận thay đổi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textHint,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCheckRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool isSelected,
    required bool showDivider,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon box
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                // Label
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                // Custom checkbox
                _buildCheckbox(isSelected),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 70, endIndent: 16, color: AppColors.divider),
      ],
    );
  }

  Widget _buildCheckbox(bool isChecked) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isChecked ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isChecked ? AppColors.primary : AppColors.divider,
          width: 1.5,
        ),
      ),
      child: isChecked
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }
}

// ─── Helper: Dashed border container ───
class DashedBorder extends StatelessWidget {
  final Widget child;
  const DashedBorder({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCCCCCC)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    const radius = Radius.circular(10);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, radius);
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}

// ─── Data models ───
class _DietItem {
  final String label;
  final IconData iconAsset;
  bool isSelected;
  _DietItem({required this.label, required this.iconAsset, required this.isSelected});
}

class _AllergyItem {
  final String label;
  final IconData icon;
  final Color iconColor;
  bool isSelected;
  _AllergyItem({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
  });
}

class _CuisineItem {
  final String label;
  bool isSelected;
  _CuisineItem({required this.label, required this.isSelected});
}
