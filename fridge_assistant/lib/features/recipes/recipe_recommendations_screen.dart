import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../models/recipe_suggestion.dart';
import '../../services/pantry_service.dart';
import '../../services/region_preference_service.dart';
import 'recipe_detail_screen.dart';

class RecipeRecommendationsScreen extends StatefulWidget {
  const RecipeRecommendationsScreen({super.key});

  @override
  State<RecipeRecommendationsScreen> createState() =>
      _RecipeRecommendationsScreenState();
}

class _RecipeRecommendationsScreenState
    extends State<RecipeRecommendationsScreen>
    with TickerProviderStateMixin {
  // ─── Constants ───
  static const int _batchSize = 5;
  static const String _tabAll = 'Tất cả';
  static const String _tabQuick = 'Món nhanh';
  static const String _tabVeg = 'Món chay';
  static const String _tabLowCal = 'Ít calo';

  static const _tabIcons = <String, IconData>{
    _tabAll: Icons.restaurant_menu,
    _tabQuick: Icons.bolt,
    _tabVeg: Icons.eco,
    _tabLowCal: Icons.local_fire_department,
  };

  // ─── State ───
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocus = FocusNode();

  List<RecipeSuggestion> _suggestions = [];
  final Set<String> _loadedRecipeKeys = <String>{};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _selectedTab = _tabAll;
  String _searchQuery = '';
  int _nextOffset = 0;
  int _ingredientCount = 0;
  RegionalProfile? _regionalProfile;
  bool _isLoadingRegion = false;
  bool _regionExpanded = false;
  Timer? _debounce;
  final Set<int> _preloadedOffsets = <int>{};

  late final AnimationController _shimmerController;
  late final AnimationController _fabController;
  late final AnimationController _cardEntryController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cardEntryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadInitialData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocus.dispose();
    _shimmerController.dispose();
    _fabController.dispose();
    _cardEntryController.dispose();
    super.dispose();
  }

  // ─── Vietnamese normalize for search ───
  static String _normalizeVietnamese(String input) {
    var text = input.toLowerCase().trim();
    const map = {
      'à': 'a', 'á': 'a', 'ạ': 'a', 'ả': 'a', 'ã': 'a',
      'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ậ': 'a', 'ẩ': 'a', 'ẫ': 'a',
      'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ặ': 'a', 'ẳ': 'a', 'ẵ': 'a',
      'è': 'e', 'é': 'e', 'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e',
      'ê': 'e', 'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ể': 'e', 'ễ': 'e',
      'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i',
      'ò': 'o', 'ó': 'o', 'ọ': 'o', 'ỏ': 'o', 'õ': 'o',
      'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ộ': 'o', 'ổ': 'o', 'ỗ': 'o',
      'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ở': 'o', 'ỡ': 'o',
      'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u',
      'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u',
      'ỳ': 'y', 'ý': 'y', 'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y',
      'đ': 'd',
    };
    map.forEach((key, value) {
      text = text.replaceAll(key, value);
    });
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }

  // ─── Data loading ───
  Future<void> fetchSuggestions(Future<void> Function() callApi) async {
    final completer = Completer<void>();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        await callApi();
      } finally {
        if (!completer.isCompleted) completer.complete();
      }
    });
    await completer.future;
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    await _loadRegionalProfile();
    final regionCacheKey = _regionalProfile?.cacheKey ?? 'all';
    final cached = await PantryService.getCachedAiSuggestions(
      regionCacheKey: regionCacheKey,
    );
    if (mounted && cached.isNotEmpty) {
      setState(() {
        _replaceSuggestions(cached);
        _nextOffset = cached.length;
        _hasMore = true;
      });
    }

    await _loadPantryIngredientCount();
    await _refreshSuggestions(limit: _batchSize, offset: 0, append: false);

    if (!mounted) return;
    setState(() => _isLoading = false);
    _fabController.forward();
    _cardEntryController.forward();
  }

  Future<void> _loadPantryIngredientCount() async {
    final items = await PantryService.getItems();
    if (!mounted) return;
    setState(() => _ingredientCount = items.length);
  }

  Future<void> _refreshSuggestions({
    required int limit,
    required int offset,
    required bool append,
  }) async {
    var nextOffset = offset;
    var hasMore = false;

    await fetchSuggestions(() async {
      final data = await PantryService.getAiSuggestions(
        limit: limit,
        offset: offset,
        regionalProfile: _regionalProfile,
      );
      if (!mounted) return;

      nextOffset = offset + data.length;
      hasMore = data.length >= limit;

      setState(() {
        if (append) {
          _appendSuggestions(data);
        } else {
          _replaceSuggestions(data);
          _preloadedOffsets.clear();
        }

        _nextOffset = nextOffset;
        _hasMore = hasMore;
      });
    });

    _preloadNextPage(nextOffset: nextOffset, hasMore: hasMore);
  }

  Future<void> _loadMoreSuggestions() async {
    if (_isLoadingMore || !_hasMore) return;

    HapticFeedback.lightImpact();
    setState(() => _isLoadingMore = true);
    final data = await PantryService.getAiSuggestions(
      limit: _batchSize,
      offset: _nextOffset,
      regionalProfile: _regionalProfile,
    );
    if (!mounted) return;

    int appended = 0;
    setState(() {
      appended = _appendSuggestions(data);
      _nextOffset += data.length;
      _hasMore = data.length >= _batchSize;
      _isLoadingMore = false;
    });

    _preloadNextPage(nextOffset: _nextOffset, hasMore: _hasMore);

    if (appended == 0 || !_hasMore) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _hasMore
                ? 'Hiện chưa có thêm món mới để gợi ý.'
                : 'Bạn đã xem hết gợi ý hiện có.',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF1F2937),
        ),
      );
    }
  }

  void _preloadNextPage({required int nextOffset, required bool hasMore}) {
    if (!hasMore || nextOffset < 0) return;
    if (_preloadedOffsets.contains(nextOffset)) return;

    _preloadedOffsets.add(nextOffset);
    unawaited(
      PantryService.getAiSuggestionsPage(
        limit: _batchSize,
        offset: nextOffset,
        regionalProfile: _regionalProfile,
      ),
    );
  }

  Future<void> _refresh() async {
    HapticFeedback.mediumImpact();
    await _loadRegionalProfile(forceRefresh: true);
    await _loadPantryIngredientCount();
    await _refreshSuggestions(limit: _batchSize, offset: 0, append: false);
    _cardEntryController
      ..reset()
      ..forward();
  }

  Future<void> _loadRegionalProfile({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoadingRegion = true);

    final profile = await RegionPreferenceService.getProfile(
      forceRefresh: forceRefresh,
    );

    if (!mounted) return;
    setState(() {
      _regionalProfile = profile;
      _isLoadingRegion = false;
    });
  }

  Future<void> _setManualRegion(VietnamRegion region) async {
    await RegionPreferenceService.setManualRegion(region);
    await _loadRegionalProfile();
    await _refreshSuggestions(limit: _batchSize, offset: 0, append: false);
  }

  Future<void> _setAutoRegion() async {
    await RegionPreferenceService.clearManualRegion();
    await _loadRegionalProfile(forceRefresh: true);
    await _refreshSuggestions(limit: _batchSize, offset: 0, append: false);
  }

  // ─── Helpers ───
  String _seasoningHintText() {
    final profile = _regionalProfile;
    if (profile == null) return '';
    return profile.seasoningPreference;
  }

  String _regionSummaryText() {
    final profile = _regionalProfile;
    if (profile == null) return 'Đang xác định vùng miền...';

    final source = profile.isAutoDetected ? 'Tự động' : 'Bạn đã chọn';
    final location = profile.detectedLocation?.trim();
    if (location != null && location.isNotEmpty) {
      return '$source: $location • ${profile.regionLabel}';
    }
    return '$source: ${profile.regionLabel}';
  }

  String _regionBadgeLabel() {
    final profile = _regionalProfile;
    if (profile == null) return 'Hợp vị Việt Nam';
    return 'Hợp vị ${profile.regionLabel}';
  }

  Color _regionBadgeColor() {
    final region = _regionalProfile?.region;
    if (region == VietnamRegion.north) return const Color(0xFFE3F2FD);
    if (region == VietnamRegion.central) return const Color(0xFFFFF3E0);
    if (region == VietnamRegion.south) return const Color(0xFFE8F5E9);
    return const Color(0xFFEFF6FF);
  }

  Color _regionBadgeTextColor() {
    final region = _regionalProfile?.region;
    if (region == VietnamRegion.north) return const Color(0xFF0D47A1);
    if (region == VietnamRegion.central) return const Color(0xFFB45309);
    if (region == VietnamRegion.south) return const Color(0xFF1B5E20);
    return const Color(0xFF1E3A8A);
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

  // ─── Search & Filter (FIXED: Vietnamese diacritics + ingredient search) ───
  List<RecipeSuggestion> get _filteredSuggestions {
    final q = _normalizeVietnamese(_searchQuery.trim());

    return _suggestions.where((recipe) {
      final nameNorm = _normalizeVietnamese(recipe.name);
      final descNorm = _normalizeVietnamese(recipe.description);
      final ingredientMatch = recipe.ingredientsUsed.any(
        (i) => _normalizeVietnamese(i).contains(q),
      );

      final inSearch = q.isEmpty ||
          nameNorm.contains(q) ||
          descNorm.contains(q) ||
          ingredientMatch;
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
      'thịt', 'bò', 'gà', 'heo', 'cá', 'tôm',
      'mực', 'hải sản', 'xúc xích', 'lạp xưởng',
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
      'salad', 'luộc', 'hấp', 'áp chảo',
      'nướng', 'rau', 'ức gà', 'bơ',
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _searchQuery = value);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
    _searchFocus.unfocus();
  }

  void _selectTab(String tab) {
    if (_selectedTab == tab) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedTab = tab);
    // Scroll to top when changing tab
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  // ─── BUILD ───
  @override
  Widget build(BuildContext context) {
    final items = _filteredSuggestions;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primary,
            backgroundColor: Colors.white,
            displacement: 60,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // ── Header ──
                SliverToBoxAdapter(
                  child: _buildHeader(),
                ),
                // ── Search bar ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: _buildSearchBar(),
                  ),
                ),
                // ── Tab chips ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildTabChips(),
                  ),
                ),
                // ── Region section ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildRegionSection(),
                  ),
                ),
                // ── Ingredient count ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: _buildIngredientCountBadge(),
                  ),
                ),
                // ── Content ──
                if (_isLoading)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildSkeletonCard(),
                        childCount: 3,
                      ),
                    ),
                  )
                else if (items.isEmpty)
                  SliverToBoxAdapter(
                    child: _buildEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _buildAnimatedRecipeCard(items[index], index);
                        },
                        childCount: items.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ── FAB ──
          Positioned(
            right: 16,
            bottom: 20,
            child: _buildFab(),
          ),
        ],
      ),
    );
  }

  // ─── Header ───
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF0FDF4)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back_ios_new, size: 16),
              ),
            ),
            const Expanded(
              child: Column(
                children: [
                  Text(
                    'Công thức cho bạn',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Gợi ý thông minh từ AI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  // ─── Search bar (FIXED: clear button, debounce) ───
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: _onSearchChanged,
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Tìm món ăn, nguyên liệu...',
          hintStyle: TextStyle(
            color: AppColors.textHint.withValues(alpha: 0.7),
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: const Icon(
              Icons.search_rounded,
              size: 22,
              color: AppColors.primary,
            ),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: _clearSearch,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.textHint.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppColors.divider.withValues(alpha: 0.5),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  // ─── Tab chips (REDESIGNED: icons, gradients, animation) ───
  Widget _buildTabChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [_tabAll, _tabQuick, _tabVeg, _tabLowCal].map((tab) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildTabChip(tab),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabChip(String title) {
    final selected = _selectedTab == title;
    final icon = _tabIcons[title] ?? Icons.restaurant;

    return GestureDetector(
      onTap: () => _selectTab(title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF66BB6A)],
                )
              : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : AppColors.divider.withValues(alpha: 0.6),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Region section (REDESIGNED: collapsible, compact) ───
  Widget _buildRegionSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header (tap to expand)
          InkWell(
            onTap: () => setState(() => _regionExpanded = !_regionExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _regionBadgeColor(),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: _regionBadgeTextColor(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _regionBadgeLabel(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _regionSummaryText(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_isLoadingRegion)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    AnimatedRotation(
                      turns: _regionExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Expanded content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    'Nêm vị ưu tiên: ${_seasoningHintText()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildRegionChip(
                        'Tự động',
                        Icons.gps_fixed,
                        _regionalProfile?.isAutoDetected ?? true,
                        () => _setAutoRegion(),
                      ),
                      _buildRegionChip(
                        'Miền Bắc',
                        Icons.north,
                        _regionalProfile?.region == VietnamRegion.north &&
                            !(_regionalProfile?.isAutoDetected ?? true),
                        () => _setManualRegion(VietnamRegion.north),
                      ),
                      _buildRegionChip(
                        'Miền Trung',
                        Icons.center_focus_strong,
                        _regionalProfile?.region == VietnamRegion.central &&
                            !(_regionalProfile?.isAutoDetected ?? true),
                        () => _setManualRegion(VietnamRegion.central),
                      ),
                      _buildRegionChip(
                        'Miền Nam',
                        Icons.south,
                        _regionalProfile?.region == VietnamRegion.south &&
                            !(_regionalProfile?.isAutoDetected ?? true),
                        () => _setManualRegion(VietnamRegion.south),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState: _regionExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionChip(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Ingredient count badge ───
  Widget _buildIngredientCountBadge() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.kitchen_rounded, size: 14, color: AppColors.primaryDark),
              const SizedBox(width: 6),
              Text(
                '${_ingredientCount > 0 ? _ingredientCount : 0} nguyên liệu trong tủ lạnh',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Empty state (REDESIGNED: animated, with retry) ───
  Widget _buildEmptyState() {
    final isSearching = _searchQuery.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 100),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Icon(
              isSearching ? Icons.search_off_rounded : Icons.restaurant_menu_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isSearching
                ? 'Không tìm thấy công thức'
                : 'Chưa có gợi ý phù hợp',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching
                ? 'Thử tìm kiếm với từ khóa khác hoặc bỏ bộ lọc.'
                : 'Hãy thêm nguyên liệu vào tủ lạnh để nhận gợi ý từ AI.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (isSearching) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: const Text('Xoá tìm kiếm'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
          if (!isSearching) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Recipe card (REDESIGNED: shadows, gradient, polish) ───
  Widget _buildAnimatedRecipeCard(RecipeSuggestion recipe, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 80).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: _buildRecipeCard(recipe),
    );
  }

  Widget _buildRecipeCard(RecipeSuggestion recipe) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image with gradient overlay ──
            Stack(
              children: [
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: _buildRecipeImage(recipe),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                        stops: const [0, 0.5, 1],
                      ),
                    ),
                  ),
                ),
                // Badges
                if (recipe.ingredientsExpiringCount > 0)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D95F), Color(0xFF00C853)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D95F).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Dùng ngay',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Region badge on image
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _regionBadgeLabel(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _regionBadgeTextColor(),
                      ),
                    ),
                  ),
                ),
                // Time overlay on bottom
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Row(
                    children: [
                      _buildOverlayChip(
                        Icons.access_time_filled,
                        recipe.cookTimeText,
                      ),
                      const SizedBox(width: 8),
                      _buildOverlayChip(
                        Icons.restaurant,
                        '${_servingEstimate(recipe)} người',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // ── Content ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                      height: 1.3,
                    ),
                  ),
                  if (recipe.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      recipe.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Ingredients chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: recipe.ingredientsUsed.take(4).map((ingredient) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFD1FAE5).withValues(alpha: 0.7),
                              const Color(0xFFBBF7D0),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          ingredient,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF065F46),
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

  Widget _buildOverlayChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ─── FAB (REDESIGNED: gradient, animation) ───
  Widget _buildFab() {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _fabController,
        curve: Curves.elasticOut,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, Color(0xFF2E7D32)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (_isLoadingMore || !_hasMore) ? null : _loadMoreSuggestions,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoadingMore)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    _hasMore ? 'Gợi ý mới' : 'Đã hết gợi ý',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Skeleton card ───
  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerBlock(height: 200, width: double.infinity),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerBlock(
                  height: 22,
                  width: 200,
                  radius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 10),
                _buildShimmerBlock(
                  height: 14,
                  width: 280,
                  radius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 14),
                Row(
                  children: List.generate(3, (index) {
                    return Container(
                      margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
                      child: _buildShimmerBlock(
                        height: 28,
                        width: 75,
                        radius: BorderRadius.circular(20),
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

  // ─── Recipe image with fallback (OPTIMIZED: cacheWidth) ───
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
        cacheWidth: 600,
        errorBuilder: (context, error, stack) => _buildRecipeImageFallback(recipe.name),
      );
    }

    return Image.network(
      primary,
      fit: BoxFit.cover,
      cacheWidth: 600,
      errorBuilder: (context, error, stack) {
        return Image.network(
          secondary,
          fit: BoxFit.cover,
          cacheWidth: 600,
          errorBuilder: (context, error, stack) => _buildRecipeImageFallback(recipe.name),
        );
      },
    );
  }
}
