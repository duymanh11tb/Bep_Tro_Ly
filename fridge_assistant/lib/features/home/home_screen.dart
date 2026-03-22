import 'package:fridge_assistant/core/localization/app_material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/google_auth_service.dart';
import '../recipes/recipe_recommendations_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bếp Trợ Lý'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: AppColors.success,
            ),
            const SizedBox(height: 16),
            const Text(
              'Đăng nhập thành công!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Chào mừng bạn đến với Bếp Trợ Lý'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RecipeRecommendationsScreen(),
                  ),
                );
              },
              child: const Text('Gợi ý món ăn'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final googleAuthService = GoogleAuthService();
    await googleAuthService.signOut();

    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/onboarding',
        (route) => false,
        arguments: {'showLogoutNotice': true},
      );
    }
  }
}
