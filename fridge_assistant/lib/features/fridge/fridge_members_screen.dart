import 'package:fridge_assistant/core/localization/app_material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/fridge_model.dart';
import '../../services/fridge_service.dart';
import '../../services/auth_service.dart';

class FridgeMembersScreen extends StatefulWidget {
  final FridgeModel fridge;

  const FridgeMembersScreen({super.key, required this.fridge});

  @override
  State<FridgeMembersScreen> createState() => _FridgeMembersScreenState();
}

class _FridgeMembersScreenState extends State<FridgeMembersScreen> {
  final FridgeService _fridgeService = FridgeService();
  bool _isLoading = false;
  late FridgeModel _currentFridge;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentFridge = widget.fridge;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService().getUser();
      final fridges = await _fridgeService.getFridges();
      final updatedFridge = fridges.firstWhere(
        (f) => f.fridgeId == _currentFridge.fridgeId,
        orElse: () => _currentFridge,
      );

      // Sort: owner first, then others
      updatedFridge.members.sort((a, b) {
        if (a.role == 'owner') return -1;
        if (b.role == 'owner') return 1;
        return 0;
      });

      if (mounted) {
        setState(() {
          _currentUserId = user?['user_id'];
          _currentFridge = updatedFridge;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showInviteDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mời thành viên mới'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: context.tr('Nhập email người dùng'),
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Mời'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      setState(() => _isLoading = true);
      final res = await _fridgeService.inviteMember(_currentFridge.fridgeId, controller.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'])),
        );
        _loadData();
      }
    }
  }

  Future<void> _removeMember(int userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xóa thành viên này khỏi tủ lạnh?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final res = await _fridgeService.removeMember(_currentFridge.fridgeId, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'])),
        );
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = _currentFridge.ownerId == _currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text('Thành viên: ${_currentFridge.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1, color: AppColors.primary),
              onPressed: _showInviteDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _currentFridge.members.length,
                itemBuilder: (context, index) {
                  final member = _currentFridge.members[index];
                  final isMemberOwner = member.role == 'owner';

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFF3F4F6)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        backgroundImage: member.photoUrl != null && member.photoUrl!.isNotEmpty
                            ? NetworkImage(member.photoUrl!)
                            : null,
                        child: member.photoUrl == null || member.photoUrl!.isEmpty
                            ? Text(member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?', 
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                            : null,
                      ),
                      title: Text(
                        member.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      subtitle: Text(
                        member.email,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isMemberOwner ? AppColors.primary.withOpacity(0.1) : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isMemberOwner ? 'Chủ tủ' : (member.status == 'pending' ? 'Chờ duyệt' : 'Thành viên'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isMemberOwner ? AppColors.primary : Colors.grey[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isOwner && !isMemberOwner && member.userId != _currentUserId) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.person_remove, color: Colors.redAccent, size: 20),
                              onPressed: () => _removeMember(member.userId),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ]
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
