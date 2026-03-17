import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/recipe_suggestion.dart';
import '../../services/pantry_service.dart';
import 'recipe_detail_screen.dart';

class RecipeRecommendationsScreen extends StatefulWidget {
  const RecipeRecommendationsScreen({super.key});

  @override
  State<RecipeRecommendationsScreen> createState() =>
      _RecipeRecommendationsScreenState();
}

class _RecipeRecommendationsScreenState
    extends State<RecipeRecommendationsScreen>
    with SingleTickerProviderStateMixin {
  static const int _batchSize = 5;
  static const String _tabAll = 'Tất cả';
  static const String _tabQuick = 'Món nhanh';
  static const String _tabVeg = 'Món chay';
  static const String _tabLowCal = 'Ít calo';

  final TextEditingController _searchController = TextEditingController();

  List<RecipeSuggestion> _suggestions = [];
  final Set<String> _loadedRecipeKeys = <String>{};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _selectedTab = _tabAll;
  String _searchQuery = '';
  int _limit = _batchSize;
  int _ingredientCount = 0;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    final cached = await PantryService.getCachedAiSuggestions();
    if (mounted && cached.isNotEmpty) {
      setState(() {
        _replaceSuggestions(cached);
        _limit = cached.length > _batchSize ? cached.length : _batchSize;
      });
    }

    await _loadPantryIngredientCount();
    await _refreshSuggestions(limit: _limit);

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadPantryIngredientCount() async {
    final items = await PantryService.getItems();
    if (!mounted) return;
    setState(() => _ingredientCount = items.length);
  }

  Future<void> _refreshSuggestions({required int limit}) async {
    final data = await PantryService.getAiSuggestions(limit: limit);
    if (!mounted) return;

    if (data.isNotEmpty) {
      setState(() {
        _replaceSuggestions(data);
      });
    }
  }

  Future<void> _loadMoreSuggestions() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    final nextLimit = _limit + _batchSize;
    final data = await PantryService.getAiSuggestions(limit: nextLimit);
    if (!mounted) return;

    int appended = 0;
    if (data.isNotEmpty) {
      setState(() {
        appended = _appendSuggestions(data);
      });
    }

    setState(() {
      _limit = nextLimit;
      _isLoadingMore = false;
    });

    if (appended == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hiện chưa có thêm món mới để gợi ý.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _refresh() async {
    await _loadPantryIngredientCount();
    await _refreshSuggestions(limit: _limit);
  }

  void _replaceSuggestions(List<RecipeSuggestion> data) {
    _suggestions = List<RecipeSuggestion>.from(data);
    _loadedRecipeKeys
      ..clear()
      ..addAll(data.map(_recipeKey));
  }

  int _appendSuggestions(List<RecipeSuggestion> data) {
    var added = 0;
    for (final recipe in data) {
      final key = _recipeKey(recipe);
      if (_loadedRecipeKeys.contains(key)) continue;
      _loadedRecipeKeys.add(key);
      _suggestions.add(recipe);
      added += 1;
    }
    return added;
  }

  String _recipeKey(RecipeSuggestion recipe) {
    if (recipe.id.isNotEmpty) return recipe.id;
    return '${recipe.name.toLowerCase()}|${recipe.description.toLowerCase()}';
  }

  List<RecipeSuggestion> get _filteredSuggestions {
    final q = _searchQuery.trim().toLowerCase();

    return _suggestions.where((recipe) {
      final inSearch =
          q.isEmpty ||
          recipe.name.toLowerCase().contains(q) ||
          recipe.description.toLowerCase().contains(q);
      if (!inSearch) return false;

      switch (_selectedTab) {
        case _tabQuick:
          return recipe.totalTimeMinutes <= 30;
        case _tabVeg:
          return _isVegetarian(recipe);
        case _tabLowCal:
          return _isLowCalorie(recipe);
        default:
          return true;
      }
    }).toList();
  }

  bool _isVegetarian(RecipeSuggestion recipe) {
    final haystack = [
      recipe.name,
      recipe.description,
      ...recipe.ingredientsUsed,
      ...recipe.ingredientsMissing,
    ].join(' ').toLowerCase();

    const meatKeywords = [
      'thịt',
      'bò',
      'gà',
      'heo',
      'cá',
      'tôm',
      'mực',
      'hải sản',
      'xúc xích',
      'lạp xưởng',
    ];

    return !meatKeywords.any(haystack.contains);
  }

  bool _isLowCalorie(RecipeSuggestion recipe) {
    final haystack = [
      recipe.name,
      recipe.description,
      ...recipe.ingredientsUsed,
    ].join(' ').toLowerCase();

    const lowCalKeywords = [
      'salad',
      'luộc',
      'hấp',
      'áp chảo',
      'nướng',
      'rau',
      'ức gà',
      'bơ',
    ];

    return lowCalKeywords.any(haystack.contains) ||
        recipe.totalTimeMinutes <= 25;
  }

  int _servingEstimate(RecipeSuggestion recipe) {
    final estimated = (recipe.ingredientsUsed.length / 2).ceil() + 1;
    if (estimated < 2) return 2;
    if (estimated > 6) return 6;
    return estimated;
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredSuggestions;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 88),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  ),
                  const Expanded(
                    child: Text(
                      'Công thức cho bạn',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm công thức...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF1F3F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabChip(_tabAll),
                    const SizedBox(width: 8),
                    _buildTabChip(_tabQuick),
                    const SizedBox(width: 8),
                    _buildTabChip(_tabVeg),
                    const SizedBox(width: 8),
                    _buildTabChip(_tabLowCal),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dựa trên ${_ingredientCount > 0 ? _ingredientCount : 0} nguyên liệu trong tủ lạnh của bạn',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              if (_isLoading)
                ...List.generate(3, (_) => _buildSkeletonCard())
              else if (items.isEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 36),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Text(
                    'Chưa có công thức phù hợp với bộ lọc hiện tại.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                ...items.map(_buildRecipeCard),
            ],
          ),
        ),
        Positioned(
          right: 14,
          bottom: 12,
          child: ElevatedButton.icon(
            onPressed: _isLoadingMore ? null : _loadMoreSuggestions,
            icon: _isLoadingMore
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Gợi ý mới'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabChip(String title) {
    final selected = _selectedTab == title;
    return ChoiceChip(
      label: Text(title),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _selectedTab = title),
      backgroundColor: const Color(0xFFF1F3F5),
      selectedColor: AppColors.primary,
      side: BorderSide.none,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.black : AppColors.textPrimary,
      ),
      visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
    );
  }

  Widget _buildRecipeCard(RecipeSuggestion recipe) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: _buildRecipeImage(recipe),
                ),
                if (recipe.ingredientsExpiringCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D95F),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Dùng ngay',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_filled,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        recipe.cookTimeText,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.restaurant,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_servingEstimate(recipe)} người',
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: recipe.ingredientsUsed.take(3).map((ingredient) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB7F5C7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          ingredient,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerBlock(height: 180, width: double.infinity),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerBlock(
                  height: 20,
                  width: 180,
                  radius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 8),
                _buildShimmerBlock(
                  height: 14,
                  width: 120,
                  radius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(3, (index) {
                    return Container(
                      margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                      child: _buildShimmerBlock(
                        height: 24,
                        width: 70,
                        radius: BorderRadius.circular(14),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerBlock({
    required double height,
    double? width,
    BorderRadius? radius,
  }) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (_, __) {
        final offset = (_shimmerController.value * 2) - 1;
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment(-1.2 + offset, -0.2),
              end: Alignment(1.2 + offset, 0.2),
              colors: const [
                Color(0xFFE5E7EB),
                Color(0xFFF8FAFC),
                Color(0xFFE5E7EB),
              ],
              stops: const [0.1, 0.45, 0.9],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipeImageFallback(String recipeName) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDBEAFE), Color(0xFFD1FAE5)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Ảnh minh họa',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Center(
              child: Icon(
                Icons.restaurant_menu,
                size: 48,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeImage(RecipeSuggestion recipe) {
    final primary = recipe.imageUrl;
    final secondary = RecipeSuggestion.fallbackImageForRecipe(recipe);

    if (primary == null || primary.isEmpty) {
      return Image.network(
        secondary,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildRecipeImageFallback(recipe.name),
      );
    }

    return Image.network(
      primary,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Image.network(
          secondary,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildRecipeImageFallback(recipe.name),
        );
      },
    );
  }
}
