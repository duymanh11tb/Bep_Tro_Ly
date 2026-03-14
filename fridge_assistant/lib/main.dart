import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'services/auth_service.dart';
import 'features/auth/auth_screen.dart';
import 'features/product/add_product_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const BepTroLyApp());
}

/// Ứng dụng Bếp Trợ Lý - Người bạn đồng hành trong gian bếp
class BepTroLyApp extends StatelessWidget {
  const BepTroLyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bếp Trợ Lý',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const CheckAuthScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const DashboardScreen(),
        '/add-product': (context) => const AddProductScreen(),
      },
    );
  }
}

class CheckAuthScreen extends StatefulWidget {
  const CheckAuthScreen({super.key});

  @override
  State<CheckAuthScreen> createState() => _CheckAuthScreenState();
}

class _CheckAuthScreenState extends State<CheckAuthScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authService = AuthService();
    final isLoggedIn = await authService.isLoggedIn();

    if (mounted) {
      if (isLoggedIn) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}
