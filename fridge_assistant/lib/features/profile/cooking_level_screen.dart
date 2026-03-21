import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';

class CookingLevelScreen extends StatefulWidget {
  const CookingLevelScreen({super.key});

  @override
  State<CookingLevelScreen> createState() => _CookingLevelScreenState();
}

class _CookingLevelScreenState extends State<CookingLevelScreen> {
  final AuthService _authService = AuthService();
  String _selectedLevel = 'Trung cấp';
  bool _isLoading = true;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _levels = [
    {
      'id': 'Người mới bắt đầu',
      'title': 'Người mới bắt đầu',
      'description': 'Món đơn giản, ít bước thực hiện và sử dụng nguyên liệu phổ biến.',
      'icon': Icons.soup_kitchen_outlined,
      'color': Colors.blue,
    },
    {
      'id': 'Trung cấp',
      'title': 'Trung cấp',
      'description': 'Đa dạng thực đơn, kỹ thuật nấu nướng cơ bản và cân bằng dinh dưỡng.',
      'icon': Icons.restaurant_outlined,
      'color': Colors.orange,
    },
    {
      'id': 'Siêu đầu bếp',
      'title': 'Siêu đầu bếp',
      'description': 'Công thức phức tạp, nhiều bước yêu cầu kỹ năng cao và trang trí tinh tế.',
      'icon': Icons.outdoor_grill_outlined, 
      'color': Colors.red,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await _authService.getUser();
    if (user != null && mounted) {
      setState(() {
        _selectedLevel = user['skill_level'] ?? 'Trung cấp';
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final result = await _authService.updateProfile({
      'skill_level': _selectedLevel,
    });

    if (mounted) {
      setState(() => _isSaving = false);
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật mức độ nấu ăn')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Lỗi khi cập nhật')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mức độ nấu ăn',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Chọn trình độ của bạn để Bếp Trợ Lý gợi ý những công thức phù hợp nhất, giúp bạn tận dụng nguyên liệu hiệu quả.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _levels.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final level = _levels[index];
                        final isSelected = _selectedLevel == level['id'];
                        return GestureDetector(
                          onTap: () => setState(() => _selectedLevel = level['id']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.grey.shade100,
                                width: 2,
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
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (level['color'] as Color).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    level['icon'],
                                    color: level['color'],
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        level['title'],
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        level['description'],
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 14,
                                            height: 14,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Xác nhận thay đổi',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
