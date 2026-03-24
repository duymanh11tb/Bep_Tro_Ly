import 'dart:convert';
import 'package:fridge_assistant/core/localization/app_material.dart';
import '../../core/localization/app_locale_controller.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_stats.dart';
import 'widgets/personal_info_section.dart';
import 'widgets/dietary_preferences_section.dart';
import 'widgets/app_settings_section.dart';
import '../../services/activity_log_service.dart';
import '../../services/app_info_service.dart';
import '../../services/app_preferences_service.dart';
import '../../services/auth_service.dart';
import '../../services/fridge_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/pantry_service.dart';

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
  String _memberSince = 'gần đây';

  String _selectedDiet = 'Bình thường';
  List<String> _selectedAllergies = [];
  List<String> _selectedCuisines = [];
  
  bool _expiryNotifications = true;
  bool _dishSuggestions = true;
  String _languageCode = AppPreferencesService.vietnamese;
  int _cookedCount = 0;
  int _pantryItems = 0;
  int _expiringSoonCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.refreshCurrentUser() ?? await _authService.getUser();
      final languageCode = await AppPreferencesService.getPreferredLanguageCode();
      final showExpired = await PantryService.getShowExpiredPreference();
      final showRecipeSuggestions =
          await PantryService.getShowRecipeSuggestionsPreference();
      final summary = await _loadProfileSummary();

      if (!mounted) return;

      if (user != null) {
        _applyUserData(user);
      }

      setState(() {
        _languageCode = languageCode;
        _expiryNotifications = showExpired;
        _dishSuggestions = showRecipeSuggestions;
        _cookedCount = summary.cookedCount;
        _pantryItems = summary.pantryItems;
        _expiringSoonCount = summary.expiringSoonCount;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        final refreshedUser = result['user'];
        if (refreshedUser is Map<String, dynamic>) {
          _applyUserData(refreshedUser);
        }
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
      final googleAuthService = GoogleAuthService();
      await googleAuthService.signOut();
      await _authService.logout();
      await PantryService.clearCache();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/onboarding',
          (route) => false,
          arguments: {'showLogoutNotice': true},
        );
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
              name: _nameController.text.isEmpty ? 'Người dùng' : _nameController.text,
              avatarUrl: _avatarUrl,
              memberSince: _memberSince,
              onEditAvatar: (filePath) => _handleAvatarChange(filePath),
            ),
            const SizedBox(height: 24),
            ProfileStats(
              cookedCount: _cookedCount,
              pantryItems: _pantryItems,
              expiringSoonCount: _expiringSoonCount,
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
              language: AppPreferencesService.labelFor(_languageCode),
              onExpiryToggle: _handleExpiryToggle,
              onSuggestionsToggle: _handleSuggestionsToggle,
              onLanguageTap: _handleLanguageSelection,
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
            Text(
              AppInfoService.versionLabel,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _applyUserData(Map<String, dynamic> user) {
    _nameController.text = user['display_name']?.toString() ?? '';
    _emailController.text = user['email']?.toString() ?? '';
    _phoneController.text = user['phone_number']?.toString() ?? user['phone']?.toString() ?? '';
    _avatarUrl = user['photo_url']?.toString();
    _memberSince = AppInfoService.formatMemberSince(
      user['created_at']?.toString(),
    );

    _selectedDiet = 'Bình thường';
    _selectedAllergies = [];
    _selectedCuisines = [];

    final dietStr = user['dietary_restrictions'] as String?;
    if (dietStr != null && dietStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(dietStr);
        if (decoded is List && decoded.isNotEmpty) {
          _selectedDiet = decoded.first.toString();
        } else if (decoded is String && decoded.isNotEmpty) {
          _selectedDiet = decoded;
        } else {
          _selectedDiet = dietStr;
        }
      } catch (_) {
        _selectedDiet = dietStr;
      }
    }

    final allergiesStr = user['allergies'] as String?;
    if (allergiesStr != null && allergiesStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(allergiesStr);
        if (decoded is List) {
          _selectedAllergies = decoded.map((e) => e.toString()).toList();
        } else {
          _selectedAllergies = allergiesStr
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {
        _selectedAllergies = allergiesStr
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

    final cuisinesStr = user['cuisine_preferences'] as String?;
    if (cuisinesStr != null && cuisinesStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(cuisinesStr);
        if (decoded is List) {
          _selectedCuisines = decoded.map((e) => e.toString()).toList();
        } else {
          _selectedCuisines = cuisinesStr
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {
        _selectedCuisines = cuisinesStr
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
  }

  Future<_ProfileSummary> _loadProfileSummary() async {
    int cookedCount = 0;
    int pantryItems = 0;
    int expiringSoonCount = 0;

    try {
      final pantryStats = await PantryService.getStats();
      pantryItems = pantryStats?.totalItems ?? 0;
      expiringSoonCount = pantryStats?.expiringSoon ?? 0;
    } catch (_) {}

    try {
      final fridgeId = await FridgeService.getActiveFridgeId();
      if (fridgeId != null) {
        final activities = await ActivityLogService().getFridgeActivities(
          fridgeId,
          type: 'cook_recipe',
        );
        cookedCount = activities.length;
      }
    } catch (_) {}

    return _ProfileSummary(
      cookedCount: cookedCount,
      pantryItems: pantryItems,
      expiringSoonCount: expiringSoonCount,
    );
  }

  Future<void> _handleExpiryToggle(bool value) async {
    setState(() => _expiryNotifications = value);
    await PantryService.setShowExpiredPreference(value);
  }

  Future<void> _handleSuggestionsToggle(bool value) async {
    setState(() => _dishSuggestions = value);
    await PantryService.setShowRecipeSuggestionsPreference(value);
  }

  Future<void> _handleLanguageSelection() async {
    final selectedCode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn ngôn ngữ ưu tiên',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Thiết lập này sẽ đồng bộ giữa hồ sơ và màn cài đặt của ứng dụng.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ...AppPreferencesService.supportedLanguages.map((option) {
                  return RadioListTile<String>(
                    value: option.code,
                    groupValue: _languageCode,
                    activeColor: AppColors.primary,
                    title: Text(option.label),
                    subtitle: Text(option.subtitle),
                    onChanged: (value) => Navigator.of(context).pop(value),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selectedCode == null || selectedCode == _languageCode) return;

    await AppLocaleController.instance.setLocaleCode(selectedCode);
    if (!mounted) return;

    setState(() => _languageCode = selectedCode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã lưu ngôn ngữ ưu tiên: ${AppPreferencesService.labelFor(selectedCode)}',
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ProfileSummary {
  final int cookedCount;
  final int pantryItems;
  final int expiringSoonCount;

  const _ProfileSummary({
    required this.cookedCount,
    required this.pantryItems,
    required this.expiringSoonCount,
  });
}
