import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_stats.dart';
import 'widgets/personal_info_section.dart';
import 'widgets/dietary_preferences_section.dart';
import 'widgets/app_settings_section.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String? _avatarUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isReadOnly = true;

  String _selectedDiet = 'Bình thường';
  List<String> _selectedAllergies = [];
  List<String> _selectedCuisines = [];
  
  bool _expiryNotifications = true;
  bool _dishSuggestions = true;
  final String _language = 'Tiếng Việt';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await _authService.getUser();
    if (user != null && mounted) {
      setState(() {
        _nameController.text = user['display_name'] ?? '';
        _emailController.text = user['email'] ?? '';
        _phoneController.text = user['phone_number'] ?? user['phone'] ?? '';
        _avatarUrl = user['photo_url'];

        // Parse Dietary Restrictions (JSON)
        final dietStr = user['dietary_restrictions'] as String?;
        if (dietStr != null && dietStr.isNotEmpty) {
          try {
            final decoded = jsonDecode(dietStr);
            if (decoded is List && decoded.isNotEmpty) {
              _selectedDiet = decoded.first;
            } else if (decoded is String) {
              _selectedDiet = decoded;
            } else {
              _selectedDiet = dietStr;
            }
          } catch (_) {
            _selectedDiet = dietStr;
          }
        }

        // Parse Allergies (JSON)
        final allergiesStr = user['allergies'] as String?;
        if (allergiesStr != null && allergiesStr.isNotEmpty) {
          try {
            final decoded = jsonDecode(allergiesStr);
            if (decoded is List) {
              _selectedAllergies = List<String>.from(decoded);
            } else {
              _selectedAllergies = allergiesStr.split(',').map((e) => e.trim()).toList();
            }
          } catch (_) {
            _selectedAllergies = allergiesStr.split(',').map((e) => e.trim()).toList();
          }
        }

        // Parse Cuisines (JSON)
        final cuisinesStr = user['cuisine_preferences'] as String?;
        if (cuisinesStr != null && cuisinesStr.isNotEmpty) {
          try {
            final decoded = jsonDecode(cuisinesStr);
            if (decoded is List) {
              _selectedCuisines = List<String>.from(decoded);
            } else {
              _selectedCuisines = cuisinesStr.split(',').map((e) => e.trim()).toList();
            }
          } catch (_) {
            _selectedCuisines = cuisinesStr.split(',').map((e) => e.trim()).toList();
          }
        }

        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    
    setState(() => _isSaving = true);
    
    try {
      final result = await _authService.updateProfile({
        'display_name': _nameController.text,
        'email': _emailController.text,
        'phone_number': _phoneController.text,
        'dietary_restrictions': jsonEncode([_selectedDiet]),
        'allergies': jsonEncode(_selectedAllergies),
        'cuisine_preferences': jsonEncode(_selectedCuisines),
      });

      if (result['success'] && mounted) {
        setState(() => _isReadOnly = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật thông tin hồ sơ'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Lỗi khi cập nhật'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleAvatarChange(String filePath) async {
    debugPrint('ProfileScreen: Changing avatar with file: $filePath');
    setState(() => _isSaving = true);
    try {
      final result = await _authService.updateAvatar(filePath);
      debugPrint('ProfileScreen: Avatar update result: ${result['success']}');
      if (result['success'] && mounted) {
        final newUser = result['user'];
        setState(() {
          _avatarUrl = newUser['photo_url'] ?? newUser['avatar_url'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật ảnh đại diện')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Lỗi cập nhật ảnh')),
        );
      }
    } catch (e) {
      debugPrint('ProfileScreen: Error updating avatar: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AuthService().logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Hồ sơ của bạn',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isSaving
                ? null
                : () async {
                    if (_isReadOnly) {
                      setState(() => _isReadOnly = false);
                    } else {
                      // Nếu đang ở chế độ chỉnh sửa, nút này có thể dùng để Hủy
                      setState(() => _isReadOnly = true);
                      // Tùy chọn: Tải lại dữ liệu cũ nếu muốn hủy thay đổi
                      _loadUserData();
                    }
                  },
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(
                    _isReadOnly ? Icons.edit_outlined : Icons.close_rounded,
                    color: _isReadOnly ? AppColors.primary : Colors.grey,
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            ProfileHeader(
              name: _nameController.text,
              avatarUrl: _avatarUrl,
              memberSince: '2023',
              onEditAvatar: (filePath) => _handleAvatarChange(filePath),
            ),
            const SizedBox(height: 24),
            const ProfileStats(
              cookedCount: 120,
              savings: '450k',
              optimizationRate: '80%',
            ),
            const SizedBox(height: 32),
            PersonalInfoSection(
              nameController: _nameController,
              emailController: _emailController,
              phoneController: _phoneController,
              isReadOnly: _isReadOnly,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Divider(color: Color(0xFFF5F5F5)),
            ),
            DietaryPreferencesSection(
              selectedDiet: _selectedDiet,
              selectedAllergies: _selectedAllergies,
              selectedCuisines: _selectedCuisines,
              onDietChanged: (diet) => setState(() => _selectedDiet = diet),
              onAddAllergy: (allergy) => setState(() => _selectedAllergies.add(allergy)),
              onRemoveAllergy: (allergy) => setState(() => _selectedAllergies.remove(allergy)),
              onCuisinesChanged: (cuisines) => setState(() => _selectedCuisines = cuisines),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Divider(color: Color(0xFFF5F5F5)),
            ),
            AppSettingsSection(
              expiryNotifications: _expiryNotifications,
              dishSuggestions: _dishSuggestions,
              language: _language,
              onExpiryToggle: (val) => setState(() => _expiryNotifications = val),
              onSuggestionsToggle: (val) => setState(() => _dishSuggestions =val),
              onLanguageTap: () {
                // Language selection
              },
            ),
            const SizedBox(height: 40),
            if (!_isReadOnly)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Cập nhật hồ sơ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _handleLogout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Đăng xuất',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Phiên bản 1.0.2',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
