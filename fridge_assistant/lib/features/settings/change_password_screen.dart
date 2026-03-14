import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isLoading = false;

  // Trạng thái validation realtime cho mật khẩu mới
  bool get _hasMinLength => _newCtrl.text.length >= 8;
  bool get _hasLetterAndDigit =>
      _newCtrl.text.contains(RegExp(r'[a-zA-Z]')) &&
      _newCtrl.text.contains(RegExp(r'[0-9]'));

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Validate
    if (_currentCtrl.text.trim().isEmpty) {
      _showError('Vui lòng nhập mật khẩu hiện tại');
      return;
    }
    if (_newCtrl.text.length < 8) {
      _showError('Mật khẩu mới phải có ít nhất 8 ký tự');
      return;
    }
    if (!_hasLetterAndDigit) {
      _showError('Mật khẩu mới phải bao gồm cả chữ và số');
      return;
    }
    if (_newCtrl.text == _currentCtrl.text) {
      _showError('Mật khẩu mới phải khác mật khẩu hiện tại');
      return;
    }
    if (_confirmCtrl.text != _newCtrl.text) {
      _showError('Mật khẩu xác nhận không khớp');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.post(
        '/api/auth/change-password',
        {
          'current_password': _currentCtrl.text,
          'new_password': _newCtrl.text,
        },
        withAuth: true,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đổi mật khẩu thành công!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else {
        _showError('Mật khẩu hiện tại không đúng. Vui lòng thử lại.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Lỗi kết nối. Vui lòng thử lại.');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Đổi mật khẩu',
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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subtitle
                  const Text(
                    'Mật khẩu mới của bạn phải khác với mật khẩu hiện tại.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ─── Mật khẩu hiện tại ───
                  const Text(
                    'Mật khẩu hiện tại',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPasswordField(
                    controller: _currentCtrl,
                    hint: 'Nhập mật khẩu hiện tại',
                    showPassword: _showCurrent,
                    onToggle: () => setState(() => _showCurrent = !_showCurrent),
                  ),
                  // Quên mật khẩu?
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tính năng đang phát triển'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Quên mật khẩu?',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── Mật khẩu mới ───
                  const Text(
                    'Mật khẩu mới',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPasswordField(
                    controller: _newCtrl,
                    hint: 'Nhập mật khẩu mới',
                    showPassword: _showNew,
                    onToggle: () => setState(() => _showNew = !_showNew),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  // Validation hints
                  _buildHint(
                    label: 'ít nhất 8 ký tự',
                    met: _hasMinLength,
                    showCheck: _newCtrl.text.isNotEmpty,
                  ),
                  const SizedBox(height: 4),
                  _buildHint(
                    label: 'bao gồm cả chữ và số',
                    met: _hasLetterAndDigit,
                    showCheck: _newCtrl.text.isNotEmpty,
                  ),
                  const SizedBox(height: 20),

                  // ─── Xác nhận mật khẩu mới ───
                  const Text(
                    'Xác nhận mật khẩu mới',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPasswordField(
                    controller: _confirmCtrl,
                    hint: 'Nhập lại mật khẩu mới',
                    showPassword: _showConfirm,
                    onToggle: () => setState(() => _showConfirm = !_showConfirm),
                    onChanged: (_) => setState(() {}),
                    matchController: _newCtrl,
                  ),
                ],
              ),
            ),
          ),

          // ─── Bottom button ───
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primaryLight,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Xác nhận thay đổi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool showPassword,
    required VoidCallback onToggle,
    void Function(String)? onChanged,
    TextEditingController? matchController,
  }) {
    // Kiểm tra match nếu có matchController
    final bool hasText = controller.text.isNotEmpty;
    final bool isMatch =
        matchController != null && controller.text == matchController.text;
    final bool showMatchError =
        matchController != null && hasText && !isMatch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: showMatchError
                  ? AppColors.error.withOpacity(0.5)
                  : (hasText && matchController != null && isMatch)
                      ? AppColors.primary.withOpacity(0.4)
                      : AppColors.divider,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: !showPassword,
            onChanged: onChanged,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 14,
                color: AppColors.textHint,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              suffixIcon: IconButton(
                icon: Icon(
                  showPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textHint,
                  size: 20,
                ),
                onPressed: onToggle,
              ),
            ),
          ),
        ),
        if (showMatchError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              'Mật khẩu không khớp',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHint({
    required String label,
    required bool met,
    required bool showCheck,
  }) {
    Color dotColor;
    if (!showCheck) {
      dotColor = AppColors.textHint;
    } else if (met) {
      dotColor = AppColors.primary;
    } else {
      dotColor = AppColors.error;
    }

    return Row(
      children: [
        Icon(
          showCheck
              ? (met ? Icons.check_circle : Icons.cancel_outlined)
              : Icons.circle,
          size: showCheck ? 14 : 8,
          color: dotColor,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: dotColor,
          ),
        ),
      ],
    );
  }
}
