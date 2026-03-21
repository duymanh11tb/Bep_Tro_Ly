import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/pantry_service.dart';
import '../../services/fridge_service.dart';
import '../../models/fridge_model.dart';

class PantryOverviewScreen extends StatefulWidget {
  final bool isSubPage;
  const PantryOverviewScreen({super.key, this.isSubPage = false});

  @override
  State<PantryOverviewScreen> createState() => _PantryOverviewScreenState();
}

class _PantryOverviewScreenState extends State<PantryOverviewScreen> {
  static const List<String> _categoryTabs = [
    'Tất cả',
    'Rau củ',
    'Thịt cá',
    'Sữa',
    'Trái cây',
    'Khác',
  ];

  final TextEditingController _searchController = TextEditingController();

  List<PantryItem> _items = [];
  bool _isLoading = true;
  String _selectedCategory = 'Tất cả';
  String _searchQuery = '';
  String _fridgeName = 'Tủ lạnh';
  FridgeModel? _activeFridge;
  bool _showExpiredItems = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadFridgeInfo();
  }

  Future<void> _loadFridgeInfo() async {
    final activeFridge = await FridgeService.getActiveFridge();
    if (activeFridge != null && mounted) {
      setState(() {
        _activeFridge = activeFridge;
        _fridgeName = activeFridge.name;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (_items.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final items = await PantryService.getItems();
      if (!mounted) return;

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openAddProduct() async {
    final result = await Navigator.pushNamed(context, '/add-product');
    if (result == true) {
      await _loadItems();
    }
  }

  Future<void> _deleteItem(PantryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa sản phẩm'),
          content: Text('Bạn có chắc muốn xóa ${item.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Xóa',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final success = await PantryService.deleteItem(item.id);
    if (!mounted) return;

    if (success) {
      setState(() {
        _items.removeWhere((e) => e.id == item.id);
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Không thể xóa sản phẩm. Vui lòng thử lại.'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  List<PantryItem> get _filteredItems {
    final q = _searchQuery.trim().toLowerCase();

    return _items.where((item) {
      final mappedCategory = _mapCategory(item.category);
      final categoryMatched =
          _selectedCategory == 'Tất cả' || mappedCategory == _selectedCategory;

      if (!categoryMatched) return false;

      // Filter expired items based on toggle
      if (!_showExpiredItems && item.isExpired) return false;

      if (q.isEmpty) return true;

      final name = item.name.toLowerCase();
      final category = item.category.toLowerCase();
      return name.contains(q) || category.contains(q);
    }).toList();
  }

  String _mapCategory(String raw) {
    final c = raw.toLowerCase();
    if (c.contains('rau') || c.contains('củ') || c.contains('nấm')) {
      return 'Rau củ';
    }
    if (c.contains('thịt') || c.contains('cá') || c.contains('hải sản')) {
      return 'Thịt cá';
    }
    if (c.contains('sữa') || c.contains('trứng')) {
      return 'Sữa';
    }
    if (c.contains('trái') || c.contains('hoa quả') || c.contains('quả')) {
      return 'Trái cây';
    }
    return 'Khác';
  }

  Color _statusColor(PantryItem item) {
    if (item.isExpired) return AppColors.error;
    if (item.isExpiringSoon) return AppColors.warning;
    return AppColors.success;
  }

  String _statusText(PantryItem item) {
    if (item.isExpired) return 'Đã hết hạn';
    if (item.isExpiringSoon) return 'Sắp hết hạn';
    return 'An toàn';
  }

  String _remainingText(PantryItem item) {
    if (item.expiryDate == null) return 'Không rõ hạn';
    if (item.isExpired) {
      return 'Quá hạn ${item.daysUntilExpiry.abs()} ngày';
    }
    if (item.daysUntilExpiry == 0) return 'Hôm nay';
    if (item.daysUntilExpiry == 1) return 'Còn 1 ngày';
    return 'Còn ${item.daysUntilExpiry} ngày';
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.isSubPage
          ? AppBar(
              title: Text(_fridgeName),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            )
          : null,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadItems,
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                if (!widget.isSubPage)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 48), // Spacer for centering
                      const Text(
                        'Kho thực phẩm',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/fridge-management',
                        ).then((_) => _loadItems()),
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                if (_activeFridge?.status == 'paused')
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.pause_circle_filled,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Tủ lạnh này đang tạm ngưng. Bạn không thể thực hiện thay đổi.',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm nguyên liệu',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF4F5F7),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Toggle to show/hide expired items
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hiển thị sản phẩm hết hạn',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Switch(
                        value: _showExpiredItems,
                        onChanged: (value) {
                          setState(() => _showExpiredItems = value);
                        },
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categoryTabs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = _categoryTabs[index];
                      final selected = category == _selectedCategory;
                      return ChoiceChip(
                        label: Text(category),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _selectedCategory = category);
                        },
                        selectedColor: AppColors.primary,
                        backgroundColor: const Color(0xFFF1F3F5),
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        side: BorderSide.none,
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else if (items.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAF8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.kitchen_outlined,
                          size: 34,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Tủ lạnh đang trống',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Nhấn nút + để thêm nguyên liệu mới',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...items.map((item) => _buildItemCard(item)),
              ],
            ),
          ),
          Positioned(
            right: 18,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: _activeFridge?.status == 'paused'
                  ? null
                  : _openAddProduct,
              backgroundColor: _activeFridge?.status == 'paused'
                  ? Colors.grey
                  : AppColors.primary,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(PantryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return const Icon(
                          Icons.inventory_2_outlined,
                          size: 18,
                          color: AppColors.textSecondary,
                        );
                      },
                    ),
                  )
                : const Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _statusText(item),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _statusColor(item),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _remainingText(item),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: _activeFridge?.status == 'paused'
                ? null
                : () => _deleteItem(item),
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.delete,
              size: 18,
              color: _activeFridge?.status == 'paused'
                  ? Colors.grey
                  : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
