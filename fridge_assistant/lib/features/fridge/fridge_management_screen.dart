import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/fridge_model.dart';
import '../../services/fridge_service.dart';
import '../../services/auth_service.dart';
import '../pantry/pantry_overview_screen.dart';
import 'activity_log_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final results = await Future.wait([
        _fridgeService.getFridges(),
        FridgeService.getActiveFridgeId(),
        AuthService().getUser(),
      ]);

      if (mounted) {
        setState(() {
          _fridges = (results[0] as List<FridgeModel>).map((f) {
            // Filter only accepted members
            f.members = f.members.where((m) => m.status == 'accepted').toList();
            // Sort: Owner first
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
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
      );
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
                      'Tủ lạnh ảo',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  _buildSectionHeader(
                    'DANH SÁCH TỦ LẠNH',
                    'Thêm tủ lạnh mới',
                    () => Navigator.pushNamed(context, '/add-fridge').then((_) => _loadData()),
                  ),
                  const SizedBox(height: 16),
                  ..._fridges.map((fridge) => _buildFridgeCard(fridge)),
                  const SizedBox(height: 32),
                  
                  _buildSectionHeader(
                    'THÀNH VIÊN CHUNG',
                    'Thêm thành viên',
                    () {
                      if (_activeFridge != null) {
                        Navigator.pushNamed(
                          context, 
                          '/manage-members', 
                          arguments: _activeFridge
                        ).then((_) => _loadData());
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  if (_activeFridge != null && _activeFridge!.members.isNotEmpty)
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
                  else if (_activeFridge == null)
                     const Center(child: Text('Chưa có tủ lạnh nào'))
                  else
                     const Center(child: Text('Chưa có thành viên nào')),
                     
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
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF00C569),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.kitchen, color: Colors.white, size: 36),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fridge.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fridge.status == 'paused' ? 'Tạm ngưng' : 'Đang hoạt động',
                    style: TextStyle(
                      fontSize: 14,
                      color: fridge.status == 'paused' ? Colors.red : Colors.black87,
                      fontWeight: fridge.status == 'paused' ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
              IconButton(
                icon: Icon(
                  Icons.history,
                  color: isSelected ? const Color(0xFF00C569) : Colors.grey[400],
                  size: 26,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ActivityLogScreen(fridgeId: fridge.fridgeId),
                    ),
                  );
                },
                tooltip: 'Nhật ký hoạt động',
              ),
            if (fridge.ownerId == _currentUserId)
              IconButton(
                icon: Icon(
                  Icons.edit_note,
                  color: isSelected ? const Color(0xFF00C569) : Colors.grey[400],
                  size: 28,
                ),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/edit-fridge',
                    arguments: fridge,
                  ).then((value) {
                    if (value != null) {
                      _loadData();
                    }
                  });
                },
              ),
            if (fridge.ownerId != _currentUserId)
              IconButton(
                icon: Icon(
                  Icons.logout,
                  color: Colors.red.withOpacity(0.7),
                  size: 24,
                ),
                onPressed: () => _handleLeaveFridge(fridge),
              ),
          ],
        ),
      ),
    );
  }
}
