import 'package:fridge_assistant/core/localization/app_material.dart';
import '../../../services/auth_service.dart';
import '../../../services/google_auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/primary_button.dart';

/// Form đăng nhập
class LoginForm extends StatefulWidget {
  final VoidCallback? onForgotPassword;
  final VoidCallback? onLoginSuccess;

  const LoginForm({super.key, this.onForgotPassword, this.onLoginSuccess});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _googleAuthService = GoogleAuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);

    try {
      final result = await _googleAuthService.signInWithGoogle();

      if (mounted) {
        setState(() => _isLoading = false);

        if (result['success']) {
          widget.onLoginSuccess?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Đăng nhập Google thất bại'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        final result = await _authService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );

        if (mounted) {
          setState(() => _isLoading = false);

          if (result['success']) {
            widget.onLoginSuccess?.call();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Đăng nhập thất bại'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã có lỗi xảy ra. Vui lòng thử lại.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Google Login Button - đặt đầu tiên để luôn thấy trên mobile
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleGoogleLogin,
            icon: Icon(Icons.login, color: Colors.blue, size: 22),
            label: const Text('Đăng nhập với Google'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Hoặc', style: AppTextStyles.bodyMedium),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          // Email Field
          CustomTextField(
            label: 'Email',
            hintText: 'Nhập email của bạn',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            controller: _emailController,
            validator: _validateEmail,
          ),
          const SizedBox(height: 20),
          // Password Field
          CustomTextField(
            label: 'Mật khẩu',
            hintText: 'Nhập mật khẩu của bạn',
            prefixIcon: Icons.lock_outline,
            isPassword: true,
            controller: _passwordController,
            textInputAction: TextInputAction.done,
            validator: _validatePassword,
            onSubmitted: (_) => _handleLogin(),
          ),
          const SizedBox(height: 20),
          // Login Button
          PrimaryButton(
            text: 'Đăng nhập',
            isLoading: _isLoading,
            onPressed: _handleLogin,
          ),
          const SizedBox(height: 16),
          // Forgot Password Link
          Center(
            child: GestureDetector(
              onTap: widget.onForgotPassword,
              child: Text('Quên mật khẩu?', style: AppTextStyles.link),
            ),
          ),
        ],
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email không hợp lệ';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    if (value.length < 6) {
      return 'Mật khẩu phải có ít nhất 6 ký tự';
    }
    return null;
  }
}
