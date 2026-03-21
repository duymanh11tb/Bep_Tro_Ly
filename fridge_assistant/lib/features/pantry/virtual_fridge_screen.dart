import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/pantry_service.dart';

class VirtualFridgeScreen extends StatefulWidget {
  const VirtualFridgeScreen({super.key});

  @override
  State<VirtualFridgeScreen> createState() => _VirtualFridgeScreenState();
}

class _VirtualFridgeScreenState extends State<VirtualFridgeScreen> {
  static const String _filterUrgent = 'Khẩn cấp';
  static const String _filterAll = 'Tất cả';
  static const String _filterVegetable = 'Rau củ';
  static const String _filterExpired = 'Đã hết hạn';

  List<PantryItem> _items = [];
  bool _isLoading = true;
  String _selectedFilter = _filterUrgent;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    if (_items.isEmpty) {
      setState(() => _isLoading = true);
    }
    final items = await PantryService.getExpiringItems(days: 7);
    // Also load all items to find expired ones
    final allItems = await PantryService.getItems();
    final expiredOnly = allItems.where((item) => item.isExpired).toList();
    if (!mounted) return;

    setState(() {
      _items = items;
      _expiredItems = expiredOnly;
      _isLoading = false;
    });
  }

  List<PantryItem> _expiredItems = [];

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
    if (_selectedFilter == _filterExpired) {
      return _expiredItems;
    }
    return _items.where((item) {
      switch (_selectedFilter) {
        case _filterUrgent:
          return item.daysUntilExpiry <= 1;
        case _filterVegetable:
          return _mapCategory(item.category) == _filterVegetable;
        default:
          return true;
      }
    }).toList();
  }

  int get _urgentCount {
    return _items.where((item) => item.daysUntilExpiry <= 1).length;
  }

  int get _vegetableCount {
    return _items
        .where((item) => _mapCategory(item.category) == _filterVegetable)
        .length;
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

  // _statusText was removed as it is not used.

  String _remainingText(PantryItem item) {
    if (item.expiryDate == null) return 'HSD: Không rõ';
    if (item.daysUntilExpiry < 0) return 'HSD: Quá hạn';
    if (item.daysUntilExpiry == 0) return 'HSD : Hôm nay';
    if (item.daysUntilExpiry == 1) return 'HSD : Ngày mai';
    return 'HSD : ${item.daysUntilExpiry} ngày';
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;
    final subtitle = _urgentCount == 0
        ? 'Không có nguyên liệu cần dùng ngay'
        : '$_urgentCount nguyên liệu cần dùng ngay';

    return RefreshIndicator(
      onRefresh: _loadItems,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: IconButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sắp hết hạn',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(_filterUrgent, _urgentCount),
                const SizedBox(width: 8),
                _buildFilterChip(_filterAll, _items.length),
                const SizedBox(width: 8),
                _buildFilterChip(_filterVegetable, _vegetableCount),
                const SizedBox(width: 8),
                _buildFilterChip(_filterExpired, _expiredItems.length),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildWarningCard(_urgentCount),
          const SizedBox(height: 8),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 36),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (items.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Column(
                children: [
                  Icon(Icons.inventory_2_outlined, color: AppColors.textHint),
                  SizedBox(height: 8),
                  Text(
                    'Không có nguyên liệu phù hợp',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            )
          else
            ...items.map(_buildItemCard),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String title, int count) {
    final isSelected = _selectedFilter == title;
    return ChoiceChip(
      label: Text('$title ($count)'),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = title),
      backgroundColor: const Color(0xFFE5E7EB),
      selectedColor: const Color(0xFF212121),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      showCheckmark: false,
      visualDensity: const VisualDensity(horizontal: -1.5, vertical: -2),
    );
  }

  Widget _buildWarningCard(int urgentCount) {
    final message = urgentCount == 0
        ? 'Hiện tại không có nguyên liệu nào cần xử lý gấp.'
        : '$urgentCount nguyên liệu sẽ hết hạn trong 24h tới. Hãy sử dụng hoặc chế biến ngay.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEEBEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_rounded, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hành động ngay!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB91C1C),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(PantryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEFF2)),
      ),
      child: Row(
        children: [
          _buildItemImage(item),
          const SizedBox(width: 12),
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
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Số lượng: ${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _remainingText(item),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(item),
                  ),
                ),
              ],
            ),
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

  Widget _buildItemImage(PantryItem item) {
    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          item.imageUrl!,
          width: 78,
          height: 62,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildImageFallback(),
        ),
      );
    }
    return _buildImageFallback();
  }

  Widget _buildImageFallback() {
    return Container(
      width: 78,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.inventory_2_outlined,
        size: 22,
        color: AppColors.textSecondary,
      ),
    );
  }
}
