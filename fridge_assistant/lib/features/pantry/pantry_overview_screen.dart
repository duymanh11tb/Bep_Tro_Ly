import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/pantry_service.dart';

class PantryOverviewScreen extends StatefulWidget {
  const PantryOverviewScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final items = await PantryService.getItems();
    if (!mounted) return;

    setState(() {
      _items = items;
      _isLoading = false;
    });
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

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadItems,
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              const Center(
                child: Text(
                  'Tủ lạnh ảo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
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
                    child: CircularProgressIndicator(color: AppColors.primary),
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
            onPressed: _openAddProduct,
            backgroundColor: AppColors.primary,
            shape: const CircleBorder(),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
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
            onPressed: () => _deleteItem(item),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}
