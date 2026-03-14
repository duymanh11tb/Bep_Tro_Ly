import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/pantry_service.dart';

class AccountInfoScreen extends StatefulWidget {
  final String userName;
  final String? avatarUrl;

  const AccountInfoScreen({
    super.key,
    required this.userName,
    this.avatarUrl,
  });

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;

  bool _isLoading = false;

  // Chế độ ăn
  final List<String> _dietOptions = ['Bình thường', 'Ăn chay', 'Eat clean'];
  String _selectedDiet = 'Bình thường';

  // Dị ứng / Kiêng - các tag có thể thêm/bỏ
  final List<String> _allAllergyOptions = [
    'Đậu phộng',
    'Hải sản',
    'Sữa & Chế phẩm',
    'Gluten',
    'Đậu nành',
    'Trứng',
  ];
  final List<String> _selectedAllergies = ['Đậu phộng', 'Hải sản'];

  // Stats giả lập (có thể kết nối API sau)
  int _dishCount = 120;
  String _moneySaved = '360k';
  String _cleanRate = '80%';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.userName);
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController(text: '0912 345 678');
    _loadUserInfo();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final authService = AuthService();
    final user = await authService.getUser();
    if (user != null && mounted) {
      setState(() {
        _nameCtrl.text = user['display_name'] ?? widget.userName;
        _emailCtrl.text = user['email'] ?? '';
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập họ và tên'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    // Giả lập gọi API
    await Future.delayed(const Duration(milliseconds: 900));

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Đã cập nhật thông tin thành công'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Đăng xuất',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất không?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authService = AuthService();
      await authService.logout();
      await PantryService.clearCache();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (route) => false);
      }
    }
  }

  void _showAddAllergySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chọn dị ứng / kiêng',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _allAllergyOptions.map((option) {
                  final isSelected = _selectedAllergies.contains(option);
                  return GestureDetector(
                    onTap: () {
                      setModal(() {
                        if (isSelected) {
                          _selectedAllergies.remove(option);
                        } else {
                          _selectedAllergies.add(option);
                        }
                      });
                      setState(() {});
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Xong', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Thông tin của bạn',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ─── Header section: avatar + name + stats ───
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                children: [
                  // Avatar
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: AppColors.primaryLight,
                          backgroundImage: widget.avatarUrl != null
                              ? NetworkImage(widget.avatarUrl!)
                              : null,
                          child: widget.avatarUrl == null
                              ? Text(
                                  _nameCtrl.text.isNotEmpty
                                      ? _nameCtrl.text[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.edit, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Name
                  Text(
                    _nameCtrl.text,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        icon: Icons.restaurant_menu,
                        value: '$_dishCount',
                        label: 'Món ăn đã nấu',
                        color: const Color(0xFF4CAF50),
                      ),
                      _buildStatDivider(),
                      _buildStatCard(
                        icon: Icons.savings_outlined,
                        value: _moneySaved,
                        label: 'Tiết kiệm',
                        color: const Color(0xFF2196F3),
                      ),
                      _buildStatDivider(),
                      _buildStatCard(
                        icon: Icons.recycling,
                        value: _cleanRate,
                        label: 'Tỉ lệ sạch tủ',
                        color: const Color(0xFF4CAF50),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ─── Form section ───
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin cá nhân',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Họ và tên
                  _buildFormField(
                    label: 'Họ và tên',
                    controller: _nameCtrl,
                    hint: 'Nhập họ và tên',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),

                  // Email
                  _buildFormField(
                    label: 'Email',
                    controller: _emailCtrl,
                    hint: 'example@gmail.com',
                    readOnly: true,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),

                  // Số điện thoại
                  _buildFormField(
                    label: 'Số điện thoại',
                    controller: _phoneCtrl,
                    hint: '0912 345 678',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 18),

                  // Chế độ ăn
                  const Text(
                    'Chế độ ăn',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: _dietOptions.map((diet) {
                      final isSelected = _selectedDiet == diet;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedDiet = diet),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.divider,
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            diet,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Dị ứng / Kiêng
                  const Text(
                    'Dị ứng/ Kiêng',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      // Selected allergy chips
                      ..._selectedAllergies.map((allergy) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                allergy,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => setState(
                                    () => _selectedAllergies.remove(allergy)),
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      // "Thêm" chip for remaining options
                      ..._allAllergyOptions
                          .where((o) => !_selectedAllergies.contains(o))
                          .take(1)
                          .map((option) {
                        return GestureDetector(
                          onTap: _showAddAllergySheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Text(
                              option,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }),
                      // "+ Thêm" button if there are more options
                      if (_selectedAllergies.length < _allAllergyOptions.length)
                        GestureDetector(
                          onTap: _showAddAllergySheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.primary.withOpacity(0.5)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add,
                                    color: AppColors.primary, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Thêm',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── Action Buttons ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Lưu button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Lưu',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Đăng xuất button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _handleLogout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        'Đăng xuất',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: AppColors.divider,
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? AppColors.backgroundSecondary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: TextStyle(
              fontSize: 14,
              color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 14,
                color: AppColors.textHint,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            ),
          ),
        ),
      ],
    );
  }
}
