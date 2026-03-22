import 'dart:convert';
import 'package:fridge_assistant/core/localization/app_material.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/primary_button.dart';

class EatingPreferencesScreen extends StatefulWidget {
  const EatingPreferencesScreen({super.key});

  @override
  State<EatingPreferencesScreen> createState() => _EatingPreferencesScreenState();
}

class _EatingPreferencesScreenState extends State<EatingPreferencesScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isSaving = false;

  String _dietaryPattern = 'Bình thường';
  List<String> _allergies = [];
  List<String> _cuisines = [];
  final TextEditingController _otherAllergyController = TextEditingController();

  final List<Map<String, dynamic>> _dietOptions = [
    {'name': 'Bình thường', 'icon': Icons.restaurant},
    {'name': 'Ăn chay', 'icon': Icons.eco_outlined},
    {'name': 'Eat Clean', 'icon': Icons.health_and_safety_outlined},
  ];

  final List<Map<String, dynamic>> _allergyOptions = [
    {'name': 'Đậu phộng', 'icon': Icons.radio_button_checked},
    {'name': 'Sữa & chế phẩm', 'icon': Icons.local_drink_outlined},
    {'name': 'Hải sản', 'icon': Icons.water_drop_outlined},
  ];

  final List<String> _cuisineOptions = [
    'Việt Nam', 'Hàn Quốc', 'Nhật Bản', 'Trung Quốc', 'Món Âu'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _otherAllergyController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final user = await _authService.getUser();
    if (user != null) {
      setState(() {
        // Xử lý Dietary Restrictions
        final dietStr = user['dietary_restrictions'] as String?;
        if (dietStr != null && dietStr.isNotEmpty) {
          try {
            final decoded = jsonDecode(dietStr);
            if (decoded is List && decoded.isNotEmpty) {
              _dietaryPattern = decoded.first;
            } else if (decoded is String) {
              _dietaryPattern = decoded;
            } else {
              _dietaryPattern = dietStr;
            }
          } catch (_) {
            _dietaryPattern = dietStr;
          }
        } else {
          _dietaryPattern = 'Bình thường';
        }

        // Xử lý Allergies
        final allergiesStr = user['allergies'] as String?;
        if (allergiesStr != null && allergiesStr.isNotEmpty) {
          try {
            final decoded = jsonDecode(allergiesStr);
            if (decoded is List) {
              _allergies = List<String>.from(decoded);
            } else {
              _allergies = allergiesStr.split(',').map((e) => e.trim()).toList();
            }
          } catch (_) {
            _allergies = allergiesStr.split(',').map((e) => e.trim()).toList();
          }
        }

        // Xử lý Cuisine Preferences
        final cuisinesStr = user['cuisine_preferences'] as String?;
        if (cuisinesStr != null && cuisinesStr.isNotEmpty) {
          try {
            final decoded = jsonDecode(cuisinesStr);
            if (decoded is List) {
              _cuisines = List<String>.from(decoded);
            } else {
              _cuisines = cuisinesStr.split(',').map((e) => e.trim()).toList();
            }
          } catch (_) {
            _cuisines = cuisinesStr.split(',').map((e) => e.trim()).toList();
          }
        }
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    
    // Lưu dưới dạng JSON array để tương thích với cột JSON của MySQL/TiDB
    final result = await _authService.updateProfile({
      'dietary_restrictions': jsonEncode([_dietaryPattern]),
      'allergies': jsonEncode(_allergies),
      'cuisine_preferences': jsonEncode(_cuisines),
    });

    if (mounted) {
      setState(() => _isSaving = false);
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật sở thích ăn uống!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Cập nhật thất bại'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: const Text('Sở thích ăn uống'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chọn các chế độ ăn uống và nguyên liệu bạn muốn tránh. Bếp trợ lý sẽ gợi ý công thức phù hợp nhất cho bạn.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 24),
            
            _buildSectionHeader('CHẾ ĐỘ ĂN'),
            _buildDietSelection(),
            
            const SizedBox(height: 24),
            _buildSectionHeader('DỊ ỨNG VÀ NGUYÊN LIỆU CẦN TRÁNH'),
            _buildAllergySelection(),
            
            const SizedBox(height: 24),
            _buildSectionHeader('ẨM THỰ YÊU THÍCH'),
            _buildCuisineSelection(),
            
            const SizedBox(height: 40),
            PrimaryButton(
              text: 'Xác nhận thay đổi',
              isLoading: _isSaving,
              onPressed: _handleSave,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: AppTextStyles.inputLabel.copyWith(
          color: AppColors.textSecondary.withValues(alpha: 0.7),
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildDietSelection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: _dietOptions.map((opt) {
          final isSelected = _dietaryPattern == opt['name'];
          return Column(
            children: [
              ListTile(
                leading: Icon(opt['icon'], color: isSelected ? AppColors.primary : Colors.grey),
                title: Text(opt['name'], style: AppTextStyles.bodyLarge),
                trailing: Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: isSelected ? AppColors.primary : Colors.grey[300],
                ),
                onTap: () => setState(() => _dietaryPattern = opt['name']),
              ),
              if (opt != _dietOptions.last) const Divider(height: 1, indent: 56),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAllergySelection() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: _allergyOptions.map((opt) {
              final isSelected = _allergies.contains(opt['name']);
              return Column(
                children: [
                  CheckboxListTile(
                    secondary: Icon(opt['icon'], color: isSelected ? Colors.redAccent : Colors.grey),
                    title: Text(opt['name'], style: AppTextStyles.bodyLarge),
                    value: isSelected,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _allergies.add(opt['name']);
                        } else {
                          _allergies.remove(opt['name']);
                        }
                      });
                    },
                  ),
                  if (opt != _allergyOptions.last) const Divider(height: 1, indent: 56),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _buildAddOtherAllergy(),
      ],
    );
  }

  Widget _buildAddOtherAllergy() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.add, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _otherAllergyController,
              decoration: InputDecoration(
                hintText: context.tr('Thêm nguyên liệu cần tránh khác'),
                border: InputBorder.none,
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  setState(() {
                    _allergies.add(val.trim());
                    _otherAllergyController.clear();
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCuisineSelection() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _cuisineOptions.map((cuisine) {
        final isSelected = _cuisines.contains(cuisine);
        return FilterChip(
          label: Text(cuisine),
          selected: isSelected,
          onSelected: (val) {
            setState(() {
              if (val) {
                _cuisines.add(cuisine);
              } else {
                _cuisines.remove(cuisine);
              }
            });
          },
          selectedColor: AppColors.primary.withValues(alpha: 0.2),
          checkmarkColor: AppColors.primary,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.shade200),
          ),
        );
      }).toList(),
    );
  }
}
