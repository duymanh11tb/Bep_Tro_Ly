import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/fridge_model.dart';
import '../../services/fridge_service.dart';
import '../../services/auth_service.dart';
import '../../services/pantry_service.dart';
import '../pantry/pantry_overview_screen.dart';
import 'activity_log_screen.dart';
import 'fridge_members_screen.dart';
import 'fridge_chat_screen.dart';

class FridgeManagementScreen extends StatefulWidget {
  const FridgeManagementScreen({super.key});

  @override
  State<FridgeManagementScreen> createState() => _FridgeManagementScreenState();
}

class _FridgeManagementScreenState extends State<FridgeManagementScreen> {
  final FridgeService _fridgeService = FridgeService();
  List<FridgeModel> _fridges = [];
  int? _activeFridgeId;
  int? _currentUserId;
  bool _isLoading = true;

  Map<int, bool> _unreadStatuses = {};
  StreamSubscription? _unreadSubscription;
  final ChatService _chatService = ChatService();

  // Ingredient counts per fridge
  Map<int, int> _fridgeItemCounts = {};
  Map<int, int> _fridgeExpiringCounts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _unreadSubscription = _chatService.unreadUpdateStream.listen((_) {
      _loadUnreadStatuses();
    });
  }

  @override
  void dispose() {
    _unreadSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    if (_fridges.isEmpty) {
      setState(() => _isLoading = true);
    }
    
    try {
      final results = await Future.wait([
        _fridgeService.getFridges(),
        FridgeService.getActiveFridgeId(),
        AuthService().getUser(),
      ]);

      if (mounted) {
        setState(() {
          _fridges = (results[0] as List<FridgeModel>).map((f) {
            f.members = f.members.where((m) => m.status == 'accepted').toList();
            f.members.sort((a, b) {
              if (a.role == 'owner') return -1;
              if (b.role == 'owner') return 1;
              return 0;
            });
            return f;
          }).toList();
          _activeFridgeId = results[1] as int?;
          _currentUserId = (results[2] as Map<String, dynamic>?)?['user_id'];
          
          if (_activeFridgeId == null && _fridges.isNotEmpty) {
            _activeFridgeId = _fridges.first.fridgeId;
            FridgeService.setActiveFridge(_activeFridgeId!);
          }
          _isLoading = false;
        });
        _loadUnreadStatuses();
      }

      // Load item counts in background
      _loadItemCounts();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadItemCounts() async {
    final counts = <int, int>{};
    final expiringCounts = <int, int>{};
    
    for (final fridge in _fridges) {
      try {
        final items = await PantryService.getItemsForFridge(fridge.fridgeId);
        counts[fridge.fridgeId] = items.length;
        expiringCounts[fridge.fridgeId] = items.where((item) => item.isExpiringSoon || item.isExpired).length;
      } catch (_) {
        counts[fridge.fridgeId] = 0;
        expiringCounts[fridge.fridgeId] = 0;
      }
    }
    
    if (mounted) {
      setState(() {
        _fridgeItemCounts = counts;
        _fridgeExpiringCounts = expiringCounts;
      });
    }
  }

  Future<void> _loadUnreadStatuses() async {
    if (_fridges.isEmpty) return;
    try {
      final statuses = await _chatService.getUnreadStatuses(_fridges.map((f) => f.fridgeId).toList());
      if (mounted) {
        setState(() {
          _unreadStatuses = statuses;
        });
      }
    } catch (e) {
      debugPrint('Error loading unread statuses: $e');
    }
  }

  Future<void> _handleSelectFridge(FridgeModel fridge) async {
    await FridgeService.setActiveFridge(fridge.fridgeId);
    if (mounted) {
      setState(() => _activeFridgeId = fridge.fridgeId);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PantryOverviewScreen(isSubPage: true),
        ),
      ).then((_) => _loadItemCounts());
    }
  }

  Future<void> _handleLeaveFridge(FridgeModel fridge) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rời khỏi tủ lạnh'),
        content: Text('Bạn có chắc muốn rời khỏi tủ "${fridge.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rời khỏi', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final result = await _fridgeService.removeMember(fridge.fridgeId, _currentUserId!);
    
    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã rời khỏi tủ lạnh thành công')),
        );
        _loadData();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    }
  }

  FridgeModel? get _activeFridge {
    if (_activeFridgeId == null || _fridges.isEmpty) return null;
    try {
      return _fridges.firstWhere((f) => f.fridgeId == _activeFridgeId);
    } catch (_) {
      return _fridges.isEmpty ? null : _fridges.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Tủ lạnh ảo',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: Material(
        color: AppColors.background,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C569)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF00C569),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                children: [
                  const Center(
                    child: Text(
                      'Chọn tủ lạnh để xem và quản lý nguyên liệu',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildSectionHeader(
                    'DANH SÁCH TỦ LẠNH',
                    'Thêm tủ lạnh mới',
                    () => Navigator.pushNamed(context, '/add-fridge').then((_) => _loadData()),
                  ),
                  const SizedBox(height: 16),
                  ..._fridges.map((fridge) => _buildFridgeCard(fridge)),
                  
                  if (_fridges.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.kitchen_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text(
                            'Chưa có tủ lạnh nào',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Nhấn "Thêm tủ lạnh mới" để bắt đầu quản lý thực phẩm',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 32),
                  
                  if (_activeFridge != null) ...[
                    _buildSectionHeader(
                      'THÀNH VIÊN CHUNG',
                      'Quản lý',
                      () {
                        Navigator.pushNamed(
                          context, 
                          '/manage-members', 
                          arguments: _activeFridge
                        ).then((_) => _loadData());
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    if (_activeFridge!.members.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: _activeFridge!.members.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final member = entry.value;
                            return Column(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  leading: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: const Color(0xFFE5E7EB),
                                    backgroundImage: member.photoUrl != null && member.photoUrl!.isNotEmpty
                                        ? NetworkImage(member.photoUrl!)
                                        : null,
                                    child: member.photoUrl == null || member.photoUrl!.isEmpty
                                        ? const Icon(Icons.person, color: Colors.grey)
                                        : null,
                                  ),
                                  title: Text(
                                    member.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${member.role == 'owner' ? 'Chủ tủ' : 'Thành viên'} ${member.status == 'pending' ? '(Đang chờ)' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: member.role == 'owner' ? AppColors.primary : AppColors.textSecondary,
                                      fontWeight: member.role == 'owner' ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (idx < _activeFridge!.members.length - 1)
                                  const Divider(height: 1, indent: 20, endIndent: 20, color: Color(0xFFF3F4F6)),
                              ],
                            );
                          }).toList(),
                        ),
                      )
                    else
                      const Center(child: Text('Chưa có thành viên nào')),
                  ],
                     
                  const SizedBox(height: 100),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String actionLabel, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8E8E93),
            letterSpacing: 0.5,
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Row(
            children: [
              const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF00C569)),
              const SizedBox(width: 4),
              Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00C569),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFridgeCard(FridgeModel fridge) {
    bool isSelected = _activeFridgeId == fridge.fridgeId;
    final itemCount = _fridgeItemCounts[fridge.fridgeId] ?? 0;
    final expiringCount = _fridgeExpiringCounts[fridge.fridgeId] ?? 0;
    
    return GestureDetector(
      onTap: () => _handleSelectFridge(fridge),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFFFF5) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00C569) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00C569)
                        : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.kitchen,
                    color: isSelected ? Colors.white : const Color(0xFF00C569),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              fridge.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C569),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Đang chọn',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fridge.status == 'paused' ? 'Tạm ngưng' : 'Đang hoạt động',
                        style: TextStyle(
                          fontSize: 13,
                          color: fridge.status == 'paused' ? Colors.red : AppColors.textSecondary,
                          fontWeight: fridge.status == 'paused' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.7) : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildStatItem(
                    Icons.inventory_2_outlined,
                    '$itemCount',
                    'nguyên liệu',
                    AppColors.primary,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: const Color(0xFFE5E7EB),
                  ),
                  _buildStatItem(
                    Icons.warning_amber_rounded,
                    '$expiringCount',
                    'sắp hết hạn',
                    expiringCount > 0 ? AppColors.warning : AppColors.textSecondary,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: const Color(0xFFE5E7EB),
                  ),
                  _buildStatItem(
                    Icons.people_outlined,
                    '${fridge.members.length}',
                    'thành viên',
                    Colors.blue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.add_shopping_cart,
                    label: 'Thêm nguyên liệu',
                    onTap: () async {
                      await FridgeService.setActiveFridge(fridge.fridgeId);
                      if (mounted) {
                        setState(() => _activeFridgeId = fridge.fridgeId);
                        final result = await Navigator.pushNamed(context, '/add-product');
                        if (result == true) _loadItemCounts();
                      }
                    },
                    isPrimary: true,
                  ),
                ),
                const SizedBox(width: 8),
                _buildIconAction(
                  icon: Icons.history,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ActivityLogScreen(fridgeId: fridge.fridgeId),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Stack(
                  children: [
                    _buildIconAction(
                      icon: Icons.chat_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FridgeChatScreen(fridge: fridge),
                          ),
                        ).then((_) => _loadUnreadStatuses());
                      },
                    ),
                    if (_unreadStatuses[fridge.fridgeId] ?? false)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                _buildIconAction(
                  icon: Icons.people_alt_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FridgeMembersScreen(fridge: fridge),
                      ),
                    ).then((_) => _loadData());
                  },
                ),
                if (fridge.ownerId == _currentUserId) ...[
                  const SizedBox(width: 8),
                  _buildIconAction(
                    icon: Icons.edit_note,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/edit-fridge',
                        arguments: fridge,
                      ).then((value) {
                        if (value != null) _loadData();
                      });
                    },
                  ),
                ],
                if (fridge.ownerId != _currentUserId) ...[
                  const SizedBox(width: 8),
                  _buildIconAction(
                    icon: Icons.logout,
                    color: Colors.red,
                    onTap: () => _handleLeaveFridge(fridge),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF00C569) : const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isPrimary ? Colors.white : AppColors.textPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconAction({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: color ?? AppColors.textSecondary,
        ),
      ),
    );
  }
}
