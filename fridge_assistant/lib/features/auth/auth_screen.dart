import 'package:fridge_assistant/core/localization/app_material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/support_service.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/auth_tab_switcher.dart';
import 'widgets/login_form.dart';
import 'widgets/register_form.dart';

/// Màn hình xác thực với tab switching giữa Đăng nhập và Đăng ký
class AuthScreen extends StatefulWidget {
  final int initialTabIndex;

  const AuthScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late int _selectedTabIndex;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              // App Logo
              const AppLogo(showTagline: false),
              const SizedBox(height: 8),
              // Subtitle
              Text(
                'Đăng nhập hoặc tạo tài khoản mới',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Tab Switcher
              AuthTabSwitcher(
                selectedIndex: _selectedTabIndex,
                onTabChanged: (index) {
                  setState(() => _selectedTabIndex = index);
                },
              ),
              const SizedBox(height: 32),
              // Form Content
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.1, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _selectedTabIndex == 0
                    ? LoginForm(
                        key: const ValueKey('login'),
                        onForgotPassword: _handleForgotPassword,
                        onLoginSuccess: _handleLoginSuccess,
                      )
                    : RegisterForm(
                        key: const ValueKey('register'),
                        onForgotPassword: _handleForgotPassword,
                        onRegisterSuccess: _handleRegisterSuccess,
                      ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleForgotPassword() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Quên mật khẩu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nhập email đăng ký để mở yêu cầu hỗ trợ đặt lại mật khẩu.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.tr('Email đăng ký'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Tiếp tục'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (!mounted || email == null || email.isEmpty) return;

    final success = await SupportService.requestPasswordReset(email: email);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã mở ứng dụng email để gửi yêu cầu đặt lại mật khẩu.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    await Clipboard.setData(
      const ClipboardData(text: SupportService.supportEmail),
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Không mở được email. Đã sao chép địa chỉ hỗ trợ để bạn liên hệ thủ công.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleLoginSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đăng nhập thành công!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  void _handleRegisterSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đăng ký thành công!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }
}
