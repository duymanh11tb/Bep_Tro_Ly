import 'dart:async';

import 'package:fridge_assistant/core/localization/app_material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/recipe_suggestion.dart';
import '../../services/pantry_service.dart';
import '../../services/fridge_service.dart';
import '../../services/region_preference_service.dart';
import '../../widgets/fridge_selector.dart';
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
  String? _loadError;
  int? _selectedFridgeId;
  int _limit = _batchSize;
  int _ingredientCount = 0;
  RecipeSuggestionMode _suggestionMode = RecipeSuggestionMode.pantry;
  String _selectedRegionCode = 'south';
  late final AnimationController _shimmerController;
  Timer? _cooldownTicker;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _syncCooldownTicker();
    _loadInitialData();
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _searchController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    // Get active fridge ID as default
    _selectedFridgeId = await FridgeService.getActiveFridgeId();
    final profile = await RegionPreferenceService.getProfile();
    _selectedRegionCode = _regionCodeFromProfile(profile);

    final cached = await PantryService.getCachedRecipeSuggestions(
      mode: _suggestionMode,
      fridgeId: _selectedFridgeId,
      region: _selectedRegionCode,
    );
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
    final items = await PantryService.getItems(fridgeId: _selectedFridgeId);
    if (!mounted) return;
    setState(() => _ingredientCount = items.length);
  }

  Future<void> _refreshSuggestions({required int limit}) async {
    try {
      final data = await PantryService.getRecipeSuggestions(
        mode: _suggestionMode,
        limit: limit,
        fridgeId: _selectedFridgeId,
        region: _selectedRegionCode,
      );
      if (!mounted) return;

      setState(() {
        _replaceSuggestions(data);
        _loadError = null;
      });
      _syncCooldownTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
      _syncCooldownTicker();
    }
  }

  Future<void> _loadMoreSuggestions() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    final nextLimit = _limit + _batchSize;
    final excludes = _suggestions.map((e) => e.name).toList();
    try {
      final data = await PantryService.getRecipeSuggestions(
        mode: _suggestionMode,
        limit: _batchSize,
        fridgeId: _selectedFridgeId,
        region: _selectedRegionCode,
        refreshToken: DateTime.now().millisecondsSinceEpoch.toString(),
        excludeRecipeNames: excludes,
      );
      if (!mounted) return;

      setState(() {
        _appendSuggestions(data);
        _limit = nextLimit;
        _loadError = null;
      });
      _syncCooldownTicker();

      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hiện chưa có thêm công thức mới phù hợp lúc này.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() => _loadError = message);
      _syncCooldownTicker();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _refresh() async {
    if (_suggestionMode == RecipeSuggestionMode.pantry) {
      await _loadPantryIngredientCount();
    }
    await _refreshSuggestions(limit: _limit);
  }

  Future<void> _switchSuggestionMode(RecipeSuggestionMode mode) async {
    if (_suggestionMode == mode) return;
    setState(() {
      _suggestionMode = mode;
      _isLoading = true;
      _loadError = null;
      _limit = _batchSize;
      _suggestions = [];
      _loadedRecipeKeys.clear();
    });

    if (_suggestionMode == RecipeSuggestionMode.pantry) {
      await _loadPantryIngredientCount();
    } else {
      setState(() => _ingredientCount = 0);
    }

    final cached = await PantryService.getCachedRecipeSuggestions(
      mode: _suggestionMode,
      fridgeId: _selectedFridgeId,
      region: _selectedRegionCode,
    );
    if (!mounted) return;

    if (cached.isNotEmpty) {
      setState(() => _replaceSuggestions(cached));
    }
    await _refreshSuggestions(limit: _limit);
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _switchRegion(String regionCode) async {
    if (_selectedRegionCode == regionCode) return;
    setState(() {
      _selectedRegionCode = regionCode;
      _isLoading = true;
      _loadError = null;
      _limit = _batchSize;
      _suggestions = [];
      _loadedRecipeKeys.clear();
    });

    final cached = await PantryService.getCachedRecipeSuggestions(
      mode: _suggestionMode,
      fridgeId: _selectedFridgeId,
      region: _selectedRegionCode,
    );
    if (!mounted) return;

    if (cached.isNotEmpty) {
      setState(() => _replaceSuggestions(cached));
    }
    await _refreshSuggestions(limit: _limit);
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  String _regionCodeFromProfile(RegionalProfile profile) {
    switch (profile.region) {
      case VietnamRegion.north:
        return 'north';
      case VietnamRegion.central:
        return 'central';
      case VietnamRegion.south:
        return 'south';
    }
  }

  String _regionLabel(String code) {
    switch (code) {
      case 'north':
        return 'Miền Bắc';
      case 'central':
        return 'Miền Trung';
      default:
        return 'Miền Nam';
    }
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

  Future<void> _handleFeedback(RecipeSuggestion recipe, String feedback) async {
    final success = await PantryService.recordSuggestionFeedback(
      recipeName: recipe.name,
      feedback: feedback,
    );
    if (success && mounted) {
      setState(() {
        recipe.status = feedback;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            feedback == 'liked'
                ? 'Đã thêm vào mục yêu thích!'
                : 'Đã ghi nhận phản hồi của bạn.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
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

  bool _isCooldownError(String? message) {
    if (message == null) return false;
    final normalized = message.toLowerCase();
    return normalized.contains('thử lại sau') &&
        (normalized.contains('vượt quota') ||
            normalized.contains('chạm quota') ||
            normalized.contains('resource_exhausted'));
  }

  void _syncCooldownTicker() {
    if (!PantryService.hasActiveRecipeCooldown) {
      _cooldownTicker?.cancel();
      _cooldownTicker = null;
      return;
    }

    _cooldownTicker ??= Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        _cooldownTicker = null;
        return;
      }

      if (!PantryService.hasActiveRecipeCooldown) {
        timer.cancel();
        _cooldownTicker = null;
        setState(() {
          if (_isCooldownError(_loadError)) {
            _loadError = null;
          }
        });
        return;
      }

      setState(() {});
    });
  }

  String? _displayLoadError() {
    if (_isCooldownError(_loadError)) {
      return PantryService.currentRecipeCooldownMessage ?? _loadError;
    }
    return _loadError;
  }

  String _emptyStateMessage() {
    final displayError = _displayLoadError();
    if (displayError != null && displayError.trim().isNotEmpty) {
      return displayError;
    }

    if (_suggestionMode == RecipeSuggestionMode.pantry && _ingredientCount == 0) {
      return 'Không tìm thấy nguyên liệu để gợi ý. Hãy thêm thức ăn vào tủ lạnh nhé!';
    }

    if (_searchQuery.trim().isNotEmpty || _selectedTab != _tabAll) {
      return 'Chưa có công thức phù hợp với bộ lọc hiện tại.';
    }

    return _suggestionMode == RecipeSuggestionMode.pantry
        ? 'Chưa tìm được công thức phù hợp với nguyên liệu đang có trong tủ.'
        : 'Chưa có công thức phù hợp cho vùng miền này.';
  }

  Widget _buildEmptyStateCard() {
    final displayError = _displayLoadError();
    final isError = displayError != null && displayError.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(top: 36),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError ? AppColors.error.withValues(alpha: 0.25) : AppColors.divider,
        ),
      ),
      child: Text(
        isError ? displayError : _emptyStateMessage(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isError ? AppColors.error : AppColors.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredSuggestions;
    final cooldownSeconds = PantryService.recipeCooldownRemainingSeconds;
    final isCooldownActive = cooldownSeconds > 0;
    final safeArea = MediaQuery.of(context).padding;
    final bottomListPadding = safeArea.bottom + 116;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primary,
              child: ListView(
                padding: EdgeInsets.fromLTRB(14, 8, 14, bottomListPadding),
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
                  if (_suggestionMode == RecipeSuggestionMode.pantry) ...[
                    FridgeSelector(
                      selectedFridgeId: _selectedFridgeId,
                      isCompact: true,
                      onSelected: (fridge) {
                        setState(() {
                          _selectedFridgeId = fridge.fridgeId;
                          _isLoading = true;
                          _loadError = null;
                          _limit = _batchSize;
                          _suggestions = [];
                          _loadedRecipeKeys.clear();
                        });
                        _refresh().then((_) {
                          if (mounted) setState(() => _isLoading = false);
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: _buildModeChip(
                          title: 'Theo tủ lạnh',
                          selected: _suggestionMode == RecipeSuggestionMode.pantry,
                          onTap: () => _switchSuggestionMode(
                            RecipeSuggestionMode.pantry,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildModeChip(
                          title: 'Theo vùng miền',
                          selected: _suggestionMode == RecipeSuggestionMode.region,
                          onTap: () => _switchSuggestionMode(
                            RecipeSuggestionMode.region,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_suggestionMode == RecipeSuggestionMode.region) ...[
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildRegionChip('north'),
                          const SizedBox(width: 8),
                          _buildRegionChip('central'),
                          const SizedBox(width: 8),
                          _buildRegionChip('south'),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: context.tr('Tìm kiếm công thức...'),
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
                    _suggestionMode == RecipeSuggestionMode.pantry
                        ? 'Dựa trên ${_ingredientCount > 0 ? _ingredientCount : 0} nguyên liệu trong tủ lạnh của bạn'
                        : 'Khám phá món ăn ${_regionLabel(_selectedRegionCode)} phù hợp bữa cơm hằng ngày',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    _suggestionMode == RecipeSuggestionMode.pantry
                        ? 'Ứng dụng ưu tiên công thức phù hợp từ nguyên liệu hiện có và tự động lấy thêm từ nguồn recipe khi cần.'
                        : 'Ứng dụng ưu tiên công thức vùng miền từ nguồn recipe để bạn chọn nhanh cho bữa cơm hằng ngày.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoading)
                    ...List.generate(3, (_) => _buildSkeletonCard())
                  else if (items.isEmpty)
                    _buildEmptyStateCard()
                  else
                    ...items.map(_buildRecipeCard),
                ],
              ),
            ),
            Positioned(
              right: 14,
              bottom: safeArea.bottom + 12,
              child: ElevatedButton.icon(
                onPressed: (_isLoadingMore || isCooldownActive)
                    ? null
                    : _loadMoreSuggestions,
                icon: _isLoadingMore
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        isCooldownActive ? Icons.timer_outlined : Icons.auto_awesome,
                        size: 16,
                      ),
                label: Text(
                  isCooldownActive
                      ? 'Thử lại sau ${cooldownSeconds}s'
                      : 'Xem thêm công thức',
                ),
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
        ),
      ),
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

  Widget _buildModeChip({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildRegionChip(String regionCode) {
    final selected = _selectedRegionCode == regionCode;
    return ChoiceChip(
      label: Text(_regionLabel(regionCode)),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => _switchRegion(regionCode),
      backgroundColor: const Color(0xFFF1F3F5),
      selectedColor: AppColors.primary,
      side: BorderSide.none,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppColors.textPrimary,
      ),
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
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flash_on, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Tương thích ${recipe.matchPercentage}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  if (recipe.cuisines.isNotEmpty || recipe.dishTypes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...recipe.cuisines.map((c) => _buildBadge(c, const Color(0xFFFFE0B2))),
                            ...recipe.dishTypes.take(2).map((t) => _buildBadge(t, const Color(0xFFE1F5FE))),
                          ],
                        ),
                      ),
                    ),
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
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFE0E0E0)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _handleFeedback(recipe, 'disliked'),
                        icon: Icon(
                          recipe.status == 'disliked'
                              ? Icons.thumb_down
                              : Icons.thumb_down_outlined,
                          size: 18,
                          color: recipe.status == 'disliked'
                              ? Colors.red
                              : Colors.grey,
                        ),
                        label: Text(
                          'Không thích',
                          style: TextStyle(
                            fontSize: 12,
                            color: recipe.status == 'disliked'
                                ? Colors.red
                                : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _handleFeedback(recipe, 'liked'),
                        icon: Icon(
                          recipe.status == 'liked'
                              ? Icons.thumb_up
                              : Icons.thumb_up_outlined,
                          size: 18,
                          color: recipe.status == 'liked'
                              ? AppColors.primary
                              : Colors.grey,
                        ),
                        label: Text(
                          'Thích',
                          style: TextStyle(
                            fontSize: 12,
                            color: recipe.status == 'liked'
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ],
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
      builder: (context, child) {
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

  Widget _buildRecipeImage(RecipeSuggestion recipe) {
    if (recipe.imageUrl == null || recipe.imageUrl!.isEmpty) {
      return _buildRecipeImageFallback(recipe.name);
    }
    return Image.network(
      recipe.imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          _buildRecipeImageFallback(recipe.name),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
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
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: 40,
          color: Colors.blue.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
