import 'package:fridge_assistant/core/localization/app_material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/primary_button.dart';
import '../auth/auth_screen.dart';

/// Màn hình chào mừng / Onboarding
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _didHandleRouteArgs = false;
  bool _isLogoutDialogVisible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didHandleRouteArgs) return;
    _didHandleRouteArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    final showLogoutNotice = args is Map && args['showLogoutNotice'] == true;

    if (showLogoutNotice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _isLogoutDialogVisible = true;
        showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Đăng xuất thành công'),
            content: const Text('Bạn đã đăng xuất hoàn toàn khỏi Google.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        ).whenComplete(() {
          _isLogoutDialogVisible = false;
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted || !_isLogoutDialogVisible) return;
          Navigator.of(context, rootNavigator: true).pop();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // App Logo
              const AppLogo(showTagline: true),
              const SizedBox(height: 40),
              // Hero Image
              Expanded(child: _buildHeroImage()),
              const SizedBox(height: 32),
              // Welcome Text
              _buildWelcomeText(),
              const SizedBox(height: 32),
              // CTA Button
              PrimaryButton(
                text: 'Bắt đầu ngay',
                showArrow: true,
                onPressed: () => _navigateToAuth(context),
              ),
              const SizedBox(height: 16),
              // Secondary Link
              _buildSecondaryLink(context),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroImage() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.primaryLight,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Placeholder gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryLight,
                    Color.fromRGBO(76, 175, 80, 0.3),
                  ],
                ),
              ),
            ),
            // Icon placeholder
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 80,
                    color: Color.fromRGBO(76, 175, 80, 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text('🥗 🥕 🍅 🥒', style: const TextStyle(fontSize: 40)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          'Người bạn đồng hành trong gian bếp',
          style: AppTextStyles.heading2,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Theo dõi mọi nguyên liệu trong tủ lạnh của bạn một cách dễ dàng và trực quan.',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSecondaryLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Chưa có tài khoản? ', style: AppTextStyles.bodyMedium),
        GestureDetector(
          onTap: () => _navigateToAuth(context, initialTab: 0),
          child: Text(
            'Đăng nhập',
            style: AppTextStyles.link.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  void _navigateToAuth(BuildContext context, {int initialTab = 0}) {
    // Note: passing arguments to named route if generic support is needed,
    // or just push simple route. For now, simple pushNamed is easiest if we don't pass tab index
    // But since we need tab index, we might need onGenerateRoute in main.dart or pass arguments.
    // For simplicity, let's just stick to direct push for this specific screen OR fix main.dart.
    // Given main.dart simple routes, let's use:
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AuthScreen(initialTabIndex: initialTab),
      ),
    );
  }
}
