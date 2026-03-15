import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/shopping_list_item.dart';

/// Màn hình chi tiết món ăn: hiển thị thông tin món + danh sách nguyên liệu cần mua
class DishDetailScreen extends StatefulWidget {
  final ShoppingListSection section;

  const DishDetailScreen({super.key, required this.section});

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  late List<ShoppingListItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.section.items.map((i) => i.copyWith()).toList();
  }

  void _toggleItem(ShoppingListItem item) {
    setState(() {
      final idx = _items.indexWhere((e) => e.id == item.id);
      if (idx >= 0) {
        _items[idx] = _items[idx].copyWith(isChecked: !_items[idx].isChecked);
      }
    });
  }

  int get _checkedCount => _items.where((i) => i.isChecked).length;

  @override
  Widget build(BuildContext context) {
    final info = widget.section.recipeInfo;
    final hasRecipeInfo = info != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context, _items),
        ),
        title: Text(
          widget.section.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ──── Thông tin món: phần ăn, thời gian, độ khó ────
            if (hasRecipeInfo) ...[
              _buildRecipeInfoCard(info!),
              const SizedBox(height: 24),
            ],

            // ──── Mô tả món ăn ────
            if (info?.description != null && info!.description!.isNotEmpty) ...[
              _buildSectionTitle('Giới thiệu món'),
              const SizedBox(height: 8),
              _buildDescriptionCard(info.description!),
              const SizedBox(height: 24),
            ],

            // ──── Mẹo chế biến ────
            if (info?.tips != null && info!.tips!.isNotEmpty) ...[
              _buildSectionTitle('Mẹo chế biến'),
              const SizedBox(height: 8),
              _buildTipsCard(info.tips!),
              const SizedBox(height: 24),
            ],

            // ──── Nguyên liệu cần mua ────
            _buildSectionTitle('Nguyên liệu cần mua (${_items.length} mục)'),
            const SizedBox(height: 12),
            _buildIngredientsList(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildRecipeInfoCard(RecipeInfo info) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildInfoChip(Icons.person_outline, '${info.servings} phần ăn'),
          const SizedBox(width: 12),
          _buildInfoChip(Icons.schedule, '${info.cookTime} phút'),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: info.difficulty == 'easy'
                    ? AppColors.primaryLight
                    : info.difficulty == 'hard'
                        ? AppColors.error.withValues(alpha: 0.12)
                        : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                info.difficultyLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: info.difficulty == 'easy'
                      ? AppColors.primary
                      : info.difficulty == 'hard'
                          ? AppColors.error
                          : AppColors.warning,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildTipsCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: AppColors.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsList() {
    return Column(
      children: _items.map((item) => _buildIngredientRow(item)).toList(),
    );
  }

  Widget _buildIngredientRow(ShoppingListItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _toggleItem(item),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: item.isChecked
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.inputBorder,
                width: item.isChecked ? 1.5 : 1,
              ),
              color: item.isChecked
                  ? AppColors.primaryLight.withValues(alpha: 0.3)
                  : AppColors.inputBackground,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: item.isChecked,
                    onChanged: (_) => _toggleItem(item),
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: item.isChecked
                              ? AppColors.textHint
                              : AppColors.textPrimary,
                          decoration: item.isChecked
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (item.detail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.detail,
                          style: TextStyle(
                            fontSize: 13,
                            color: item.isChecked
                                ? AppColors.textHint
                                : AppColors.textSecondary,
                            decoration: item.isChecked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    '$_checkedCount/${_items.length} đã mua',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Đã thêm nguyên liệu vào danh sách mua sắm'),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart, size: 20),
                label: const Text('Thêm vào danh sách mua sắm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
