import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/fridge_item.dart';
import '../../models/recipe_suggestion.dart';
import '../../services/auth_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/greeting_section.dart';
import 'widgets/stat_cards.dart';
import 'widgets/quick_actions.dart';
import 'widgets/expiring_items.dart';
import 'widgets/ai_suggestion_carousel.dart';
import 'widgets/fridge_stats.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentNavIndex = 0;
  String _userName = 'User';

  // Sample data - sau này sẽ fetch từ API
  final List<FridgeItem> _expiringItems = [
    FridgeItem(
      id: '1',
      name: 'Sữa tươi',
      imageUrl: null,
      quantity: 1,
      unit: 'hộp',
      expiryDate: DateTime.now().add(const Duration(days: 1)),
      category: 'Sữa',
      addedDate: DateTime.now().subtract(const Duration(days: 5)),
    ),
    FridgeItem(
      id: '2',
      name: 'Cà chua',
      imageUrl: null,
      quantity: 5,
      unit: 'quả',
      expiryDate: DateTime.now().add(const Duration(days: 2)),
      category: 'Rau củ',
      addedDate: DateTime.now().subtract(const Duration(days: 3)),
    ),
    FridgeItem(
      id: '3',
      name: 'Sữa chua',
      imageUrl: null,
      quantity: 4,
      unit: 'hộp',
      expiryDate: DateTime.now().add(const Duration(days: 2)),
      category: 'Sữa',
      addedDate: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];

  final List<RecipeSuggestion> _suggestions = [
    RecipeSuggestion(
      id: '1',
      name: 'Canh chua cá lóc',
      imageUrl: null,
      description: 'Dùng bạc hà và cá lóc đang có sẵn',
      ingredientsUsed: ['cá lóc', 'bạc hà', 'cà chua', 'đậu bắp'],
      cookTimeMinutes: 45,
      difficulty: 'Dễ',
      matchPercentage: 85,
      ingredientsExpiringCount: 3,
    ),
    RecipeSuggestion(
      id: '2',
      name: 'Thịt kho tàu',
      imageUrl: null,
      description: 'Món ăn truyền thống đậm đà',
      ingredientsUsed: ['thịt ba chỉ', 'trứng', 'nước dừa'],
      cookTimeMinutes: 60,
      difficulty: 'Trung bình',
      matchPercentage: 70,
      ingredientsExpiringCount: 2,
    ),
    RecipeSuggestion(
      id: '3',
      name: 'Rau muống xào tỏi',
      imageUrl: null,
      description: 'Đơn giản, nhanh gọn, bổ dưỡng',
      ingredientsUsed: ['rau muống', 'tỏi'],
      cookTimeMinutes: 15,
      difficulty: 'Dễ',
      matchPercentage: 100,
      ingredientsExpiringCount: 1,
    ),
  ];

  final List<FridgeCategory> _fridgeCategories = [
    FridgeCategory(
      name: 'Rau củ',
      icon: Icons.eco,
      count: 12,
      color: Colors.green,
    ),
    FridgeCategory(
      name: 'Thịt & cá',
      icon: Icons.set_meal,
      count: 5,
      color: Colors.red,
    ),
    FridgeCategory(
      name: 'Sữa & trứng',
      icon: Icons.egg,
      count: 8,
      color: Colors.orange,
    ),
    FridgeCategory(
      name: 'Gia vị',
      icon: Icons.local_dining,
      count: 15,
      color: Colors.brown,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final authService = AuthService();
    final user = await authService.getUser();
    if (user != null && mounted) {
      setState(() {
        _userName = user['display_name'] ?? 'User';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _buildBody(),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() {
            _currentNavIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentNavIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildPlaceholder('Tủ lạnh');
      case 2:
        return _buildPlaceholder('Công thức');
      case 3:
        return _buildPlaceholder('Đi chợ');
      case 4:
        return _buildSettingsPage();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          DashboardHeader(
            onNotificationTap: () {
              // TODO: Show notifications
            },
          ),
          const SizedBox(height: 8),

          // Greeting
          GreetingSection(
            userName: _userName,
            statusMessage: 'Tủ lạnh đang cần sự chú ý của bạn',
          ),
          const SizedBox(height: 20),

          // Stat Cards
          const StatCards(
            recipesAvailable: 12,
            moneySaved: 450,
          ),
          const SizedBox(height: 24),

          // Quick Actions
          QuickActions(
            onScanTap: () {
              // TODO: Open scanner
            },
            onAddTap: () {
              // TODO: Add item
            },
            onSearchTap: () {
              // TODO: Search
            },
          ),
          const SizedBox(height: 24),

          // Expiring Items
          ExpiringItems(
            items: _expiringItems,
            onViewAllTap: () {
              // TODO: View all expiring
            },
          ),
          const SizedBox(height: 24),

          // AI Suggestions Carousel (auto-scroll 7 giây)
          AiSuggestionCarousel(
            suggestions: _suggestions,
            autoScrollDuration: const Duration(seconds: 7),
            onViewRecipeTap: (recipe) {
              // TODO: Show recipe detail
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Xem công thức: ${recipe.name}'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Fridge Stats
          FridgeStats(categories: _fridgeCategories),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Đang phát triển...',
            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.settings,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          const Text(
            'Cài đặt',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _handleLogout(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final authService = AuthService();
    await authService.logout();

    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/onboarding',
        (route) => false,
      );
    }
  }
}
