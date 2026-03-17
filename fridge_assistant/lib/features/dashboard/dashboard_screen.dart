import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/pantry_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/greeting_section.dart';
import 'widgets/stat_cards.dart';
import 'widgets/quick_actions.dart';
import 'widgets/ai_suggestion_carousel.dart';
import 'widgets/fridge_stats.dart';
import '../shopping/shopping_list_screen.dart';
import '../../models/recipe_suggestion.dart';
import '../meal_plan/meal_plan_screen.dart';
import '../pantry/virtual_fridge_screen.dart';
import '../pantry/pantry_overview_screen.dart';
import '../recipes/recipe_detail_screen.dart';
import '../scan/scan_ingredient_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int initialTabIndex;

  const DashboardScreen({super.key, this.initialTabIndex = 0});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late int _currentNavIndex;
  String _userName = 'User';
  String? _avatarUrl;

  // Real data from API
  bool _isLoading = true;
  List<PantryItem> _expiringItems = [];
  PantryStats? _stats;
  List<RecipeSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _currentNavIndex = widget.initialTabIndex.clamp(0, 4);
    _initSequence();
  }

  Future<void> _initSequence() async {
    // 1. Tải thông tin user & dữ liệu cache ngay lập tức
    await Future.wait([_loadUserInfo(), _loadCachedData()]);

    // 2. Refresh dữ liệu từ server trong nền
    _loadPantryData(isBackground: true);
  }

  Future<void> _loadUserInfo() async {
    final authService = AuthService();
    final user = await authService.getUser();
    if (user != null && mounted) {
      setState(() {
        _userName = user['display_name'] ?? 'User';
        _avatarUrl = user['photo_url'];
      });
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final results = await Future.wait([
        PantryService.getCachedExpiringItems(),
        PantryService.getCachedStats(),
        PantryService.getCachedAiSuggestions(),
      ]);

      if (mounted) {
        setState(() {
          _expiringItems = results[0] as List<PantryItem>;
          _stats = results[1] as PantryStats?;
          _suggestions = results[2] as List<RecipeSuggestion>;

          // Nếu có cache, tắt loading ngay để người dùng xem luôn
          if (_expiringItems.isNotEmpty ||
              _stats != null ||
              _suggestions.isNotEmpty) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading cached data: $e');
    }
  }

  Future<void> _loadPantryData({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() => _isLoading = true);
    }

    try {
      final results = await Future.wait([
        PantryService.getExpiringItems(days: 7),
        PantryService.getStats(),
        // Lấy nhiều gợi ý để người dùng vuốt xem đa dạng hơn.
        PantryService.getAiSuggestions(limit: 10),
      ]);

      if (mounted) {
        setState(() {
          _expiringItems = results[0] as List<PantryItem>;
          _stats = results[1] as PantryStats?;
          _suggestions = results[2] as List<RecipeSuggestion>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refresh() async {
    await _loadPantryData(isBackground: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: (index) => setState(() => _currentNavIndex = index),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentNavIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return const PantryOverviewScreen();
      case 2:
        return const MealPlanScreen();
      case 3:
        return ShoppingListScreen(
          onGoToFridge: (checkedCount) {
            setState(() => _currentNavIndex = 1);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('Đã thêm $checkedCount mục vào tủ lạnh.'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
          },
        );
      case 4:
        return _buildSettingsPage();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            DashboardHeader(onNotificationTap: () {}),
            const SizedBox(height: 8),

            // Greeting with avatar
            GreetingSection(
              userName: _userName,
              statusMessage: _isLoading
                  ? 'Đang tải dữ liệu...'
                  : _stats != null && _stats!.expiringSoon > 0
                  ? '${_stats!.expiringSoon} sản phẩm sắp hết hạn!'
                  : 'Tủ lạnh của bạn đang ổn định!',
              avatarUrl: _avatarUrl,
            ),
            const SizedBox(height: 20),

            // Stat Cards - show real data
            StatCards(
              recipesAvailable: _suggestions.length,
              moneySaved:
                  _stats?.expiringSoon ??
                  0, // Using expiring count as a proxy for "saved" items
            ),
            const SizedBox(height: 24),

            // Quick Actions
            QuickActions(
              onScanTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ScanIngredientScreen(),
                  ),
                );
              },
              onAddTap: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/add-product',
                );
                if (result == true) _refresh();
              },
              onSearchTap: () {},
            ),
            const SizedBox(height: 24),

            // AI Suggestions / Discovery
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : _suggestions.isEmpty
                ? _buildEmptySuggestions()
                : AiSuggestionCarousel(
                    suggestions: _suggestions,
                    autoScrollDuration: const Duration(seconds: 7),
                    onViewRecipeTap: (recipe) {
                      _openRecipeDetail(recipe);
                    },
                  ),
            const SizedBox(height: 24),

            // Expiring Items - real data
            if (!_isLoading && _expiringItems.isNotEmpty)
              _buildExpiringSection()
            else if (!_isLoading && _expiringItems.isEmpty)
              _buildNoExpiringItems(),

            const SizedBox(height: 24),

            // Fridge Stats - real data from API
            if (_stats != null && _stats!.byCategory.isNotEmpty)
              _buildRealFridgeStats()
            else
              _buildEmptyStats(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySuggestions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.primary, size: 32),
            const SizedBox(height: 8),
            const Text(
              'Chưa có gợi ý nào',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Hãy thử thêm nguyên liệu hoặc nhấn làm mới để AI bắt đầu gợi ý món ăn cho bạn nhé!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại ngay'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiringSection() {
    // Convert PantryService PantryItem to the widget's FridgeItem-like data
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Sắp hết hạn',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 260),
                      reverseTransitionDuration: const Duration(
                        milliseconds: 220,
                      ),
                      pageBuilder: (_, __, ___) => const Scaffold(
                        backgroundColor: AppColors.background,
                        body: SafeArea(child: VirtualFridgeScreen()),
                      ),
                      transitionsBuilder:
                          (_, animation, secondaryAnimation, child) {
                            final slide =
                                Tween<Offset>(
                                  begin: const Offset(0.15, 0),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutCubic,
                                  ),
                                );
                            final fade = Tween<double>(begin: 0.0, end: 1.0)
                                .animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOut,
                                  ),
                                );

                            return FadeTransition(
                              opacity: fade,
                              child: SlideTransition(
                                position: slide,
                                child: child,
                              ),
                            );
                          },
                    ),
                  );
                },
                child: const Text(
                  'Xem tất cả',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _expiringItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = _expiringItems[index];
              return _buildExpiringCard(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpiringCard(PantryItem item) {
    Color expiryColor = AppColors.textSecondary;
    if (item.isExpired) {
      expiryColor = AppColors.error;
    } else if (item.daysUntilExpiry <= 1) {
      expiryColor = AppColors.error;
    } else if (item.daysUntilExpiry <= 3) {
      expiryColor = AppColors.warning;
    }

    return GestureDetector(
      onTap: () => _openRecipesForIngredient(item),
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Container(
                height: 85,
                width: double.infinity,
                color: AppColors.backgroundSecondary,
                child: item.imageUrl != null
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _categoryIcon(item.category),
                      )
                    : _categoryIcon(item.category),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.expiryText,
                    style: TextStyle(
                      fontSize: 10,
                      color: expiryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRecipesForIngredient(PantryItem item) {
    final keyword = item.name.toLowerCase();
    final related = _suggestions.where((recipe) {
      return recipe.ingredientsUsed.any(
        (ing) => ing.toLowerCase().contains(keyword),
      );
    }).toList();

    if (related.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chưa có gợi ý nào dùng "${item.name}". Thử làm mới nhé!',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Món dùng ${item.name}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: related.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final recipe = related[index];
                      return _buildRelatedRecipeTile(recipe);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRelatedRecipeTile(RecipeSuggestion recipe) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 56,
            height: 56,
            child: recipe.imageUrl != null
                ? Image.network(
                    recipe.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.restaurant),
                  )
                : const Icon(Icons.restaurant),
          ),
        ),
        title: Text(
          recipe.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          recipe.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).pop();
          _openRecipeDetail(recipe);
        },
      ),
    );
  }

  void _openRecipeDetail(RecipeSuggestion recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
    );
  }

  Widget _categoryIcon(String category) {
    IconData icon;
    Color color;
    switch (category.toLowerCase()) {
      case 'sữa & trứng':
      case 'sữa':
        icon = Icons.egg_outlined;
        color = Colors.orange;
        break;
      case 'rau củ':
      case 'rau củ quả':
        icon = Icons.eco;
        color = Colors.green;
        break;
      case 'thịt & cá':
        icon = Icons.set_meal;
        color = Colors.red;
        break;
      default:
        icon = Icons.kitchen_outlined;
        color = AppColors.textHint;
    }
    return Center(child: Icon(icon, color: color, size: 36));
  }

  Widget _buildNoExpiringItems() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppColors.primary,
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Không có sản phẩm sắp hết hạn!',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealFridgeStats() {
    // Map icon colors for known categories
    final catIconMap = {
      'rau củ': (Icons.eco, Colors.green),
      'rau củ quả': (Icons.eco, Colors.green),
      'thịt & cá': (Icons.set_meal, Colors.red),
      'thịt': (Icons.set_meal, Colors.red),
      'sữa & trứng': (Icons.egg_outlined, Colors.orange),
      'sữa': (Icons.egg_outlined, Colors.orange),
      'gia vị': (Icons.local_dining, Colors.brown),
      'đồ uống': (Icons.local_drink, Colors.blue),
      'bánh kẹo': (Icons.cake, Colors.pink),
    };

    final categories = _stats!.byCategory.map((c) {
      final key = c.category.toLowerCase();
      final info =
          catIconMap[key] ?? (Icons.category_outlined, AppColors.primary);
      return FridgeCategory(
        name: c.category,
        icon: info.$1,
        count: c.count,
        color: info.$2,
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Thống kê tủ lạnh',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${_stats!.totalItems} sản phẩm',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FridgeStats(categories: categories),
        ],
      ),
    );
  }

  Widget _buildEmptyStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thống kê tủ lạnh',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.kitchen_outlined,
                  size: 48,
                  color: AppColors.textHint,
                ),
                SizedBox(height: 8),
                Text(
                  'Tủ lạnh đang trống',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Nhấn "Thêm món" để bắt đầu',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog() {
    final nameCtrl = TextEditingController();
    final quantityCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController(text: 'cái');
    DateTime? selectedExpiry;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Thêm sản phẩm vào tủ lạnh',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              // Name field
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Tên sản phẩm *',
                  hintText: 'VD: Cà chua, Sữa tươi...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Quantity + Unit row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: quantityCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Số lượng',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: unitCtrl,
                      decoration: InputDecoration(
                        labelText: 'Đơn vị',
                        hintText: 'cái, kg, lít...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Expiry date picker
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 3)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppColors.primary,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setModal(() => selectedExpiry = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.inputBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        selectedExpiry != null
                            ? 'Hết hạn: ${selectedExpiry!.day}/${selectedExpiry!.month}/${selectedExpiry!.year}'
                            : 'Chọn ngày hết hạn (tùy chọn)',
                        style: TextStyle(
                          fontSize: 14,
                          color: selectedExpiry != null
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng nhập tên sản phẩm'),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final success = await PantryService.addItem(
                      nameVi: name,
                      quantity: double.tryParse(quantityCtrl.text) ?? 1,
                      unit: unitCtrl.text.isEmpty ? 'cái' : unitCtrl.text,
                      expiryDate: selectedExpiry,
                    );
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Đã thêm sản phẩm!'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                      _refresh();
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lỗi thêm sản phẩm. Vui lòng thử lại.'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Thêm vào tủ lạnh',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 64, color: AppColors.textHint),
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
            style: TextStyle(color: AppColors.textSecondary),
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
          const Icon(Icons.settings, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text(
            'Cài đặt',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Đang đăng nhập: $_userName',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _handleLogout,
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
    await PantryService.clearCache();
    if (mounted) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/onboarding', (route) => false);
    }
  }
}
