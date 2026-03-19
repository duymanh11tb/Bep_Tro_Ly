import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/profile/profile_screen.dart';
import 'services/auth_service.dart';
import 'services/local_notification_service.dart';
import 'features/auth/auth_screen.dart';
import 'features/product/add_product_screen.dart';
import 'features/pantry/virtual_fridge_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/auth/change_password_screen.dart';
import 'features/profile/eating_preferences_screen.dart';
import 'features/profile/cooking_level_screen.dart';
import 'features/fridge/fridge_management_screen.dart';
import 'features/fridge/add_fridge_screen.dart';
import 'features/fridge/edit_fridge_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/fridge/manage_members_screen.dart';
import 'features/settings/help_feedback_screen.dart';
import 'models/fridge_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env");
  await LocalNotificationService.init();
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
        '/expiring-items': (context) => const Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(child: VirtualFridgeScreen()),
        ),
        '/settings': (context) => const SettingsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/change-password': (context) => const ChangePasswordScreen(),
        '/eating-preferences': (context) => const EatingPreferencesScreen(),
        '/cooking-level': (context) => const CookingLevelScreen(),
        '/fridge-management': (context) => const FridgeManagementScreen(),
        '/add-fridge': (context) => const AddFridgeScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/edit-fridge': (context) {
           final fridge = ModalRoute.of(context)!.settings.arguments as FridgeModel;
           return EditFridgeScreen(fridge: fridge);
        },
        '/manage-members': (context) {
           final fridge = ModalRoute.of(context)!.settings.arguments as FridgeModel;
           return ManageMembersScreen(fridge: fridge);
        },
        '/help-feedback': (context) => const HelpFeedbackScreen(),
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
    final isLoggedIn = await authService.validateSession();

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
