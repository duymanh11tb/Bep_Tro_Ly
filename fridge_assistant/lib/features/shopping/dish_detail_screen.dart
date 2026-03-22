import 'package:fridge_assistant/core/localization/app_material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/shopping_list_item.dart';
import 'cooking_detail_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final info = widget.section.recipeInfo;
    // Removed unused variable

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
            // ──── Ảnh món ăn ────
            if (info != null) _buildDishImage(info),
            if (info != null) const SizedBox(height: 16),

            // ──── Mô tả ngắn ────
            if (info != null) ...[
              if (info.description != null && info.description!.isNotEmpty) ...[
                Text(
                  info.description!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],

            // ──── 4 ô thông tin: Chuẩn bị / Nấu / Khẩu phần / Độ khó ────
            if (info != null) _buildInfoGrid(info),
            if (info != null) const SizedBox(height: 24),

            // ──── Mẹo chế biến ────
            if (info != null && info.tips != null && info.tips!.isNotEmpty) ...[
              _buildSectionTitle('Mẹo chế biến'),
              const SizedBox(height: 8),
              _buildTipsCard(info.tips!),
              const SizedBox(height: 24),
            ],

            // ──── Nguyên liệu ────
            _buildSectionTitle('Nguyên liệu'),
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

  /// Ảnh món ăn trên cùng (nếu có imageUrl thì load, không thì hiển thị placeholder)
  Widget _buildDishImage(RecipeInfo info) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: () {
          final imageUrl = info.imageUrl;
          if (imageUrl != null && imageUrl.isNotEmpty) {
            return Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
            );
          }
          return _buildImagePlaceholder();
        }(),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.backgroundSecondary,
      child: const Center(
        child: Icon(
          Icons.restaurant_outlined,
          size: 40,
          color: AppColors.textHint,
        ),
      ),
    );
  }

  /// Lưới 4 ô: Chuẩn bị / Nấu / Khẩu phần / Độ khó
  Widget _buildInfoGrid(RecipeInfo info) {
    final prepText = info.prepTime > 0 ? '${info.prepTime} Phút' : '--';
    final cookText = info.cookTime > 0 ? '${info.cookTime} Phút' : '--';

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildInfoBox('Chuẩn bị', prepText),
              const SizedBox(height: 10),
              _buildInfoBox('Khẩu phần', '${info.servings} Người'),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _buildInfoBox('Nấu', cookText),
              const SizedBox(height: 10),
              _buildInfoBox('Độ khó', info.difficultyLabel),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
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
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CookingDetailScreen(section: widget.section),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Bắt đầu nấu',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
