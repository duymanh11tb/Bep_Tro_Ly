import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/fridge_model.dart';
import '../../services/fridge_service.dart';

class ManageMembersScreen extends StatefulWidget {
  final FridgeModel fridge;
  const ManageMembersScreen({super.key, required this.fridge});

  @override
  State<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends State<ManageMembersScreen> {
  final _emailController = TextEditingController();
  final FridgeService _fridgeService = FridgeService();
  bool _isLoading = false;
  late List<FridgeMemberModel> _members;
  Map<String, dynamic>? _foundUser;

  @override
  void initState() {
    super.initState();
    // Only show accepted members
    _members = widget.fridge.members.where((m) => m.status == 'accepted').toList();
    _members.sort((a, b) {
      if (a.role == 'owner') return -1;
      if (b.role == 'owner') return 1;
      return 0;
    });
  }

  Future<void> _handleSearch() async {
    final query = _emailController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _foundUser = null;
    });

    try {
      final user = await _fridgeService.searchUser(query);
      setState(() {
        _foundUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleInvite() async {
    if (_foundUser == null) return;
    final identifier = _foundUser!['email'] ?? _foundUser!['phone_number'];

    setState(() => _isLoading = true);
    final result = await _fridgeService.inviteMember(widget.fridge.fridgeId, identifier);

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
        _emailController.clear();
        setState(() => _foundUser = null);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleRemove(int userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xóa thành viên này khỏi tủ lạnh?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _fridgeService.removeMember(widget.fridge.fridgeId, userId);
      if (mounted) {
        if (result['success']) {
          setState(() {
            _members.removeWhere((m) => m.userId == userId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa thành viên')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'])),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thêm thành viên',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.kitchen, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ĐANG QUẢN LÝ',
                        style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.fridge.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Email hoặc SĐT',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: 'example@gmail.com',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: _isLoading && _foundUser == null
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search, color: AppColors.primary),
                    onPressed: _isLoading ? null : _handleSearch,
                  ),
                ),
              ],
            ),
            if (_foundUser != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: _foundUser!['photo_url'] != null ? NetworkImage(_foundUser!['photo_url']) : null,
                          child: _foundUser!['photo_url'] == null ? const Icon(Icons.person) : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_foundUser!['display_name'] ?? 'Ẩn danh', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(_foundUser!['email'] ?? 'Không có email', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handleInvite,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Gửi lời mời', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
            Text(
              'THÀNH VIÊN HIỆN TẠI (${_members.length})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _members.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
                itemBuilder: (context, index) {
                  final member = _members[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundImage: member.photoUrl != null ? NetworkImage(member.photoUrl!) : null,
                      child: member.photoUrl == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(member.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${member.role == 'owner' ? 'Chủ tủ' : 'Thành viên'} ${member.status == 'pending' ? '(Đang chờ)' : ''}'),
                    trailing: member.role != 'owner' 
                        ? IconButton(
                            icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
                            onPressed: () => _handleRemove(member.userId),
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
