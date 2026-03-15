import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/shopping_list_item.dart';
import 'dish_detail_screen.dart';

/// Màn hình Danh sách mua sắm (tab Đi chợ)
class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  int _selectedTabIndex = 0; // 0: Tất cả, 1: Món ăn, 2: Tủ lạnh
  List<ShoppingListSection> _sections = [];
  List<ShoppingListItem> _allItems = [];
  String _suggestionText =
      'Dựa trên thực đơn tuần này, bạn có thể cần thêm Hành tím và Nước mắm';

  @override
  void initState() {
    super.initState();
    _loadMockData();
  }

  void _loadMockData() {
    _sections = [
      ShoppingListSection(
        title: 'Canh chua cá lóc',
        recipeInfo: RecipeInfo(
          recipeId: 'r1',
          servings: 4,
          cookTime: 25,
          difficulty: 'medium',
          description: 'Nồi canh chua cá lóc nóng hổi đặc trưng miền Nam với vị chua thanh của me, ngọt dịu của dứa, cà chua, bắp cải cùng thịt cá lóc săn chắc, đậm đà hương vị miền Tây sông nước.',
          tips: 'Để nước canh trong và cá không bị tanh, nên ướp cá sơ với muối và cho cá vào nồi khi nước sôi mạnh. Bạc hà nên bóp với muối và rửa sạch để giảm độ ngứa.',
        ),
        items: [
          ShoppingListItem(id: '1', name: 'Cá lóc', detail: 'Khúc giữa - 500g', isChecked: false, recipeId: 'r1'),
          ShoppingListItem(id: '2', name: 'Bạc hà', detail: '2 cây', isChecked: false, recipeId: 'r1'),
          ShoppingListItem(id: '3', name: 'Dọc mùng', detail: '2 cây', isChecked: false, recipeId: 'r1'),
          ShoppingListItem(id: '4', name: 'Ngò gai', detail: '1 bó nhỏ', isChecked: true, recipeId: 'r1'),
          ShoppingListItem(id: '1a', name: 'Dứa (thơm)', detail: '1/2 quả - thái lát', isChecked: false, recipeId: 'r1'),
          ShoppingListItem(id: '1b', name: 'Cà chua', detail: '2 quả - bổ múi cau', isChecked: false, recipeId: 'r1'),
          ShoppingListItem(id: '1c', name: 'Me vắt', detail: '1 thìa - vắt lấy nước', isChecked: false, recipeId: 'r1'),
        ],
      ),
      ShoppingListSection(
        title: 'Phở bò tái nạm',
        recipeInfo: RecipeInfo(
          recipeId: 'r2',
          servings: 4,
          cookTime: 240,
          difficulty: 'hard',
          description: 'Tô phở bò nóng hổi, thơm lừng với nước dùng trong veo, đậm đà, những lát bò tái mềm, nạm bò giòn sần sật.',
          tips: 'Để nước phở trong và thơm, nên hầm xương với lửa nhỏ và thường xuyên vớt bọt. Các loại gia vị khô nên rang thơm trước khi cho vào hầm.',
        ),
        items: [
          ShoppingListItem(id: '7', name: 'Xương bò', detail: '1 kg - hầm nước dùng', isChecked: false, recipeId: 'r2'),
          ShoppingListItem(id: '8', name: 'Bắp bò', detail: '300g - thái lát tái', isChecked: false, recipeId: 'r2'),
          ShoppingListItem(id: '9', name: 'Bánh phở tươi', detail: '4 phần', isChecked: false, recipeId: 'r2'),
          ShoppingListItem(id: '9a', name: 'Hành tây, gừng', detail: 'Nướng thơm cho nước dùng', isChecked: false, recipeId: 'r2'),
          ShoppingListItem(id: '9b', name: 'Hoa hồi, quế, thảo quả', detail: 'Rang thơm', isChecked: false, recipeId: 'r2'),
        ],
      ),
      ShoppingListSection(
        title: 'Bún chả Hà Nội',
        recipeInfo: RecipeInfo(
          recipeId: 'r3',
          servings: 3,
          cookTime: 45,
          difficulty: 'medium',
          description: 'Món bún chả trứ danh Hà Thành với những miếng chả heo nướng thơm lừng, chả băm đậm đà, ăn cùng bún tươi và nước chấm chua ngọt.',
          tips: 'Để chả nướng không bị khô, phết một lớp dầu ăn hoặc nước ướp trong quá trình nướng. Chọn thịt nạc vai có lẫn mỡ để chả mềm.',
        ),
        items: [
          ShoppingListItem(id: '10', name: 'Thịt ba chỉ', detail: '300g - thái lát ướp nướng', isChecked: false, recipeId: 'r3'),
          ShoppingListItem(id: '11', name: 'Thịt nạc vai xay', detail: '200g - viên chả băm', isChecked: false, recipeId: 'r3'),
          ShoppingListItem(id: '12', name: 'Bún tươi', detail: '3 phần', isChecked: false, recipeId: 'r3'),
          ShoppingListItem(id: '12a', name: 'Hành tím, tỏi', detail: 'Băm ướp thịt', isChecked: false, recipeId: 'r3'),
          ShoppingListItem(id: '12b', name: 'Nước mắm, đường, dấm', detail: 'Pha nước chấm', isChecked: false, recipeId: 'r3'),
        ],
      ),
      ShoppingListSection(
        title: 'Thịt kho tàu',
        recipeInfo: RecipeInfo(
          recipeId: 'r4',
          servings: 4,
          cookTime: 90,
          difficulty: 'easy',
          description: 'Món thịt kho Tàu đậm đà, mặn ngọt hài hòa với miếng thịt ba chỉ mềm tan, béo ngậy cùng trứng vịt luộc thấm vị.',
          tips: 'Để thịt kho mềm và thấm vị, nên chọn thịt ba chỉ có cả nạc và mỡ. Kho lửa nhỏ càng lâu thịt càng mềm.',
        ),
        items: [
          ShoppingListItem(id: '13', name: 'Thịt ba chỉ', detail: '500g - cắt miếng vuông', isChecked: false, recipeId: 'r4'),
          ShoppingListItem(id: '14', name: 'Trứng vịt', detail: '4–6 quả - luộc bóc vỏ', isChecked: false, recipeId: 'r4'),
          ShoppingListItem(id: '15', name: 'Nước dừa tươi', detail: '1 quả - hoặc 200ml', isChecked: false, recipeId: 'r4'),
          ShoppingListItem(id: '15a', name: 'Nước mắm, đường', detail: 'Ướp và nêm', isChecked: false, recipeId: 'r4'),
        ],
      ),
      ShoppingListSection(
        title: 'Gỏi cuốn tôm thịt',
        recipeInfo: RecipeInfo(
          recipeId: 'r5',
          servings: 4,
          cookTime: 30,
          difficulty: 'easy',
          description: 'Món khai vị tươi mát với tôm tươi, thịt luộc, bún và rau sống cuộn trong bánh tráng, chấm nước mắm chua ngọt.',
          tips: 'Xếp phần tôm có màu đỏ nổi bật ở ngoài cuốn sẽ đẹp mắt. Cuộn chặt tay vừa phải để cuốn không bung.',
        ),
        items: [
          ShoppingListItem(id: '16', name: 'Tôm tươi', detail: '200g - luộc bóc vỏ', isChecked: false, recipeId: 'r5'),
          ShoppingListItem(id: '17', name: 'Thịt ba chỉ', detail: '200g - luộc thái lát', isChecked: false, recipeId: 'r5'),
          ShoppingListItem(id: '18', name: 'Bánh tráng', detail: '1 gói - loại cuốn gỏi', isChecked: false, recipeId: 'r5'),
          ShoppingListItem(id: '18a', name: 'Bún tươi, xà lách, rau thơm', detail: 'Rửa sạch để ráo', isChecked: false, recipeId: 'r5'),
        ],
      ),
      ShoppingListSection(
        title: 'Cần mua thêm',
        recipeInfo: null,
        items: [
          ShoppingListItem(id: '5', name: 'Sữa tươi không đường', detail: '1 hộp 1 lít', isChecked: false),
          ShoppingListItem(id: '6', name: 'Trứng gà', detail: '1 vỉ - 10 quả', isChecked: true),
        ],
      ),
    ];
    _allItems = _sections.expand((s) => s.items).toList();
  }

  Future<void> _openDishDetail(ShoppingListSection section) async {
    final updatedItems = await Navigator.push<List<ShoppingListItem>>(
      context,
      MaterialPageRoute(
        builder: (context) => DishDetailScreen(section: section),
      ),
    );
    if (updatedItems != null && mounted) {
      setState(() {
        for (final item in updatedItems) {
          final idx = _allItems.indexWhere((e) => e.id == item.id);
          if (idx >= 0) _allItems[idx] = item;
        }
        _sections = _sections.map((sec) {
          if (sec.title != section.title) return sec;
          return ShoppingListSection(
            title: sec.title,
            recipeInfo: sec.recipeInfo,
            items: sec.items.map((i) {
              final found = updatedItems.where((u) => u.id == i.id).toList();
              return found.isEmpty ? i : found.first;
            }).toList(),
          );
        }).toList();
      });
    }
  }

  int get _checkedCount => _allItems.where((i) => i.isChecked).length;
  int get _totalCount => _allItems.length;
  int get _remainingCount => _totalCount - _checkedCount;

  /// Lọc section theo tab: 0 Tất cả, 1 Món ăn (có recipeInfo), 2 Tủ lạnh (Cần mua thêm)
  List<ShoppingListSection> get _filteredSections {
    switch (_selectedTabIndex) {
      case 1:
        return _sections.where((s) => s.isRecipeSection).toList();
      case 2:
        return _sections.where((s) => !s.isRecipeSection).toList();
      default:
        return _sections;
    }
  }

  void _toggleItem(ShoppingListItem item) {
    setState(() {
      final idx = _allItems.indexWhere((i) => i.id == item.id);
      if (idx >= 0) {
        _allItems[idx] = _allItems[idx].copyWith(isChecked: !_allItems[idx].isChecked);
      }
      _sections = _sections.map((section) {
        return ShoppingListSection(
          title: section.title,
          recipeInfo: section.recipeInfo,
          items: section.items.map((i) {
            if (i.id == item.id) return i.copyWith(isChecked: !i.isChecked);
            return i;
          }).toList(),
        );
      }).toList();
    });
  }

  void _onMoveToFridge() {
    final checked = _allItems.where((i) => i.isChecked).toList();
    if (checked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Chưa có mục nào được chọn'),
          backgroundColor: AppColors.textSecondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã chuyển ${checked.length} mục vào tủ lạnh (tính năng đang phát triển)'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ──── Header: Tiêu đề ────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(
            'Danh sách mua sắm',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),

        // ──── Tab bar: Tất cả | Món ăn | Tủ lạnh ────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _buildTab(0, 'Tất cả'),
                _buildTab(1, 'Món ăn'),
                _buildTab(2, 'Tủ lạnh'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ──── Thống kê nhanh ────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildStatChip('$_totalCount mục', AppColors.textSecondary),
              const SizedBox(width: 10),
              _buildStatChip('$_checkedCount đã mua', AppColors.primary),
              const SizedBox(width: 10),
              _buildStatChip('$_remainingCount còn lại', AppColors.warning),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ──── Danh sách + Gợi ý ────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionsList(),
                const SizedBox(height: 20),
                _buildSuggestionCard(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),

        // ──── Thanh hành động: Đã mua xong | Vào tủ lạnh ────
        _buildBottomActionBar(),
      ],
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSectionsList() {
    final sections = _filteredSections;
    if (sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.shopping_basket_outlined, size: 56, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text(
                _selectedTabIndex == 1
                    ? 'Chưa có món ăn nào trong danh sách'
                    : 'Chưa có mục nào cần mua thêm',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    // Tab Món ăn: hiển thị danh sách thẻ món, bấm vào mở màn hình chi tiết
    if (_selectedTabIndex == 1) {
      return _buildDishCards(sections);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((section) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _buildSectionCard(section),
        );
      }).toList(),
    );
  }

  /// Danh sách thẻ món ăn (tab Món ăn) – bấm vào mở chi tiết nguyên liệu
  Widget _buildDishCards(List<ShoppingListSection> sections) {
    return Column(
      children: sections.map((section) {
        final info = section.recipeInfo!;
        final checked = section.items.where((i) => i.isChecked).length;
        final total = section.items.length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openDishDetail(section),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
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
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.restaurant_menu,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 14, color: AppColors.textHint),
                              const SizedBox(width: 4),
                              Text(
                                '${info.servings} phần',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.schedule, size: 14, color: AppColors.textHint),
                              const SizedBox(width: 4),
                              Text(
                                '${info.cookTime} phút',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: info.difficulty == 'easy'
                                      ? AppColors.primaryLight
                                      : info.difficulty == 'hard'
                                          ? AppColors.error.withValues(alpha: 0.12)
                                          : const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  info.difficultyLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: info.difficulty == 'easy'
                                        ? AppColors.primary
                                        : info.difficulty == 'hard'
                                            ? AppColors.error
                                            : AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$total nguyên liệu cần mua • $checked đã mua',
                            style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textHint),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionCard(ShoppingListSection section) {
    final isRecipe = section.recipeInfo != null;
    final info = section.recipeInfo;
    final checkedInSection = section.items.where((i) => i.isChecked).length;
    final totalInSection = section.items.length;

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section: tên món + thông tin chi tiết
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isRecipe)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.restaurant_menu,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    if (isRecipe) const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        section.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$checkedInSection/$totalInSection',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (info != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline, size: 14, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(
                            '${info.servings} phần ăn',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 14, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(
                            '${info.cookTime} phút',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: info.difficulty == 'easy'
                              ? AppColors.primaryLight
                              : info.difficulty == 'hard'
                                  ? AppColors.error.withValues(alpha: 0.12)
                                  : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          info.difficultyLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: info.difficulty == 'easy'
                                ? AppColors.primary
                                : info.difficulty == 'hard'
                                    ? AppColors.error
                                    : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (!isRecipe) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Nguyên liệu linh hoạt cho bữa ăn hàng ngày',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: section.items.map((item) => _buildListItem(item)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(ShoppingListItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _toggleItem(item),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: item.isChecked ? AppColors.primary.withValues(alpha: 0.4) : AppColors.inputBorder,
                width: item.isChecked ? 1.5 : 1,
              ),
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
                const SizedBox(width: 12),
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
                        const SizedBox(height: 3),
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
                Icon(
                  Icons.drag_handle,
                  size: 20,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_outlined,
            color: Color(0xFF1976D2),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gợi ý từ Bếp Trợ Lý',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _suggestionText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1565C0),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.restaurant_outlined,
            color: const Color(0xFF1976D2).withValues(alpha: 0.7),
            size: 32,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_checkedCount',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Đã mua xong',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _onMoveToFridge,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Vào tủ lạnh',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 20,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
