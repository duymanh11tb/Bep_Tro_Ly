import 'dart:math' as math;

import 'package:fridge_assistant/core/localization/app_material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/recipe_suggestion.dart';
import '../../services/meal_plan_service.dart';
import '../../services/pantry_service.dart';
import '../recipes/recipe_detail_screen.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  static const List<String> _mealTypes = ['breakfast', 'lunch', 'dinner'];
  static const List<Map<String, String>> _dietaryOptions = [
    {'code': 'default', 'label': 'Mặc định'},
    {'code': 'vegetarian', 'label': 'Ăn chay'},
    {'code': 'weight_loss', 'label': 'Giảm cân'},
    {'code': 'eat_clean', 'label': 'Eat Clean'},
  ];

  int _selectedDayOffset = 0;
  bool _isLoading = true;
  bool _isRefreshingDiscovery = false;
  bool _isGeneratingByIngredients = false;

  List<RecipeSuggestion> _discoverySuggestions = [];
  List<RecipeSuggestion> _ingredientSuggestions = [];
  List<String> _pantryNames = [];

  final Set<String> _selectedIngredients = <String>{};
  Map<String, dynamic> _planData = <String, dynamic>{};
  String _selectedDietaryMode = 'default';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  String _newRefreshToken() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _initData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      MealPlanService.loadPlan(),
      MealPlanService.getDiscoverySuggestions(
        limit: 12,
        dietaryPreference: _effectiveDietaryPreference,
        refreshToken: _newRefreshToken(),
      ),
      PantryService.getItems(),
    ]);

    if (!mounted) return;

    final plan = results[0] as Map<String, dynamic>;
    final discovery = results[1] as List<RecipeSuggestion>;
    final pantryItems = results[2] as List<PantryItem>;

    setState(() {
      _planData = plan;
      _discoverySuggestions = discovery;
      _pantryNames =
          pantryItems
              .map((e) => e.name.trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      _isLoading = false;
    });
  }

  Future<void> _refreshDiscovery() async {
    setState(() => _isRefreshingDiscovery = true);
    final data = await MealPlanService.getDiscoverySuggestions(
      limit: 12,
      dietaryPreference: _effectiveDietaryPreference,
      refreshToken: _newRefreshToken(),
    );
    if (!mounted) return;
    setState(() {
      _discoverySuggestions = data;
      _isRefreshingDiscovery = false;
      _ingredientSuggestions = [];
    });
  }

  Future<void> _generateByIngredients() async {
    if (_selectedIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy chọn ít nhất 1 nguyên liệu để gợi ý.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isGeneratingByIngredients = true);
    final data = await MealPlanService.getSuggestionsByIngredients(
      _selectedIngredients.toList(),
      limit: 8,
      dietaryPreference: _effectiveDietaryPreference,
      refreshToken: _newRefreshToken(),
    );

    if (!mounted) return;
    final effective = data.isNotEmpty
        ? data
        : (_discoverySuggestions.isNotEmpty
              ? _discoverySuggestions.take(6).toList()
              : data);

    setState(() {
      _ingredientSuggestions = effective;
      _isGeneratingByIngredients = false;
    });

    if (effective.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tạm thời chưa có món phù hợp, vui lòng thử lại sau.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  DateTime get _selectedDate =>
      DateTime.now().add(Duration(days: _selectedDayOffset));

  String? get _effectiveDietaryPreference =>
      _selectedDietaryMode == 'default' ? null : _selectedDietaryMode;

  String get _selectedDateKey {
    final d = _selectedDate;
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }

  Map<String, dynamic> _dayPlan(String dateKey) {
    final dynamic data = _planData[dateKey];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  RecipeSuggestion? _recipeAt(String dateKey, String mealType) {
    final mealMap = _dayPlan(dateKey);
    final dynamic recipeData = mealMap[mealType];
    if (recipeData is! Map<String, dynamic>) {
      if (recipeData is Map) {
        return RecipeSuggestion.fromJson(Map<String, dynamic>.from(recipeData));
      }
      return null;
    }
    return RecipeSuggestion.fromJson(recipeData);
  }

  Future<void> _saveMealPlan(
    String dateKey,
    String mealType,
    RecipeSuggestion recipe,
  ) async {
    final dayMap = _dayPlan(dateKey);
    dayMap[mealType] = recipe.toJson();

    final next = Map<String, dynamic>.from(_planData);
    next[dateKey] = dayMap;

    setState(() => _planData = next);
    await MealPlanService.savePlan(next);
  }

  Future<void> _clearMealPlan(String dateKey, String mealType) async {
    final dayMap = _dayPlan(dateKey);
    dayMap.remove(mealType);

    final next = Map<String, dynamic>.from(_planData);
    next[dateKey] = dayMap;

    setState(() => _planData = next);
    await MealPlanService.savePlan(next);
  }

  String _mealTypeLabel(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return 'Bữa sáng';
      case 'lunch':
        return 'Bữa trưa';
      case 'dinner':
        return 'Bữa tối';
      default:
        return mealType;
    }
  }

  IconData _mealTypeIcon(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return Icons.wb_sunny_outlined;
      case 'lunch':
        return Icons.lunch_dining_outlined;
      case 'dinner':
        return Icons.nights_stay_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }

  Color _mealTypeColor(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return AppColors.warning;
      case 'lunch':
        return const Color(0xFF34A853);
      case 'dinner':
        return const Color(0xFF5B6BD5);
      default:
        return AppColors.primary;
    }
  }

  String _weekdayLabel(DateTime date) {
    const weekdays = [
      'Chủ nhật',
      'Thứ hai',
      'Thứ ba',
      'Thứ tư',
      'Thứ năm',
      'Thứ sáu',
      'Thứ bảy',
    ];
    return weekdays[date.weekday % 7];
  }

  int _caloriesOf(RecipeSuggestion recipe) {
    final total = recipe.totalTimeMinutes;
    final match = recipe.matchScore;
    return (240 + total * 3 + (120 * (1.0 - match))).toInt();
  }

  int _mealCalories(String mealType) {
    final recipe = _recipeAt(_selectedDateKey, mealType);
    if (recipe == null) return 0;
    return _caloriesOf(recipe);
  }

  int get _dailyCalories {
    var total = 0;
    for (final mealType in _mealTypes) {
      final recipe = _recipeAt(_selectedDateKey, mealType);
      if (recipe != null) total += _caloriesOf(recipe);
    }
    return total;
  }

  String _defaultMealTypeForQuickAdd() {
    for (final mealType in _mealTypes) {
      if (_recipeAt(_selectedDateKey, mealType) == null) return mealType;
    }
    return 'dinner';
  }

  Future<void> _openSuggestionSheet(String mealType) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildList(List<RecipeSuggestion> items, String emptyText) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      emptyText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final recipe = items[index];
                  return _SuggestionTile(
                    recipe: recipe,
                    onTap: () async {
                      await _saveMealPlan(_selectedDateKey, mealType, recipe);
                      if (!mounted) return;
                      Navigator.of(context).pop();
                    },
                  );
                },
              );
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Gợi ý cho ${_mealTypeLabel(mealType)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            await _refreshDiscovery();
                            if (!mounted) return;
                            setModalState(() {});
                          },
                          icon: _isRefreshingDiscovery
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: const Text('Gợi ý luôn'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: () async {
                            await _generateByIngredients();
                            if (!mounted) return;
                            setModalState(() {});
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          icon: _isGeneratingByIngredients
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.tune),
                          label: const Text('Theo nguyên liệu'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Chọn nguyên liệu bạn đang có',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_pantryNames.isEmpty)
                      const Text(
                        'Bạn chưa có nguyên liệu trong tủ. Vẫn có thể dùng nút Gợi ý luôn.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _pantryNames.map((name) {
                          final selected = _selectedIngredients.contains(name);
                          return FilterChip(
                            selected: selected,
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _selectedIngredients.add(name);
                                } else {
                                  _selectedIngredients.remove(name);
                                }
                              });
                              setModalState(() {});
                            },
                            label: Text(name),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Kết quả gợi ý ngay',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    buildList(
                      _discoverySuggestions.take(6).toList(),
                      'Chưa có gợi ý khám phá lúc này.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Kết quả theo nguyên liệu',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    buildList(
                      _ingredientSuggestions,
                      'Chọn nguyên liệu rồi nhấn Theo nguyên liệu để xem món phù hợp.',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final date = _selectedDate;

    return RefreshIndicator(
      onRefresh: _initData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          const Text(
            'Lịch ăn uống',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final d = DateTime.now().add(Duration(days: index));
                final selected = index == _selectedDayOffset;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDayOffset = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 72,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.25),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'T${d.weekday}',
                          style: TextStyle(
                            fontSize: 12,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 28,
                            height: 1,
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${_weekdayLabel(date)}, ${date.day} tháng ${date.month}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$_dailyCalories kcal',
                style: const TextStyle(
                  fontSize: 22,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _dietaryOptions.map((option) {
                final code = option['code']!;
                final selected = _selectedDietaryMode == code;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(option['label']!),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) async {
                      setState(() => _selectedDietaryMode = code);
                      await _refreshDiscovery();
                    },
                    backgroundColor: const Color(0xFFF1F3F5),
                    selectedColor: AppColors.primary,
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          for (final mealType in _mealTypes) ...[
            _MealSection(
              title: _mealTypeLabel(mealType),
              icon: _mealTypeIcon(mealType),
              iconColor: _mealTypeColor(mealType),
              caloriesText: _mealCalories(mealType) > 0
                  ? '${_mealCalories(mealType)} kcal'
                  : '-- kcal',
              recipe: _recipeAt(_selectedDateKey, mealType),
              onPick: () => _openSuggestionSheet(mealType),
              onOpenDetail: (recipe) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(recipe: recipe),
                  ),
                );
              },
              onDropRecipe: (recipe) {
                _saveMealPlan(_selectedDateKey, mealType, recipe);
              },
              onClear: () => _clearMealPlan(_selectedDateKey, mealType),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Gợi ý cho bạn',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  _openSuggestionSheet(_defaultMealTypeForQuickAdd());
                },
                child: const Text(
                  'Xem thêm',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Text(
            'Giữ và kéo món vào khung bữa ăn để lên lịch nhanh.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 248,
            child: _discoverySuggestions.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có dữ liệu gợi ý.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _discoverySuggestions.length.clamp(0, 8),
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final recipe = _discoverySuggestions[index];
                      return _DiscoveryCard(
                        recipe: recipe,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  RecipeDetailScreen(recipe: recipe),
                            ),
                          );
                        },
                        onQuickAdd: () {
                          final slot = _defaultMealTypeForQuickAdd();
                          _saveMealPlan(_selectedDateKey, slot, recipe);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Đã thêm "${recipe.name}" vào ${_mealTypeLabel(slot)}.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String caloriesText;
  final RecipeSuggestion? recipe;
  final VoidCallback onPick;
  final ValueChanged<RecipeSuggestion> onOpenDetail;
  final ValueChanged<RecipeSuggestion> onDropRecipe;
  final VoidCallback onClear;

  const _MealSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.caloriesText,
    required this.recipe,
    required this.onPick,
    required this.onOpenDetail,
    required this.onDropRecipe,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              caloriesText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DragTarget<RecipeSuggestion>(
          onAcceptWithDetails: (details) {
            onDropRecipe(details.data);
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isHovering
                    ? AppColors.primary.withOpacity(0.06)
                    : Colors.transparent,
              ),
              child: CustomPaint(
                painter: _DashedRoundedRectPainter(
                  color: isHovering
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.5),
                  radius: 16,
                  strokeWidth: isHovering ? 2 : 1.4,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: recipe == null
                      ? InkWell(
                          onTap: onPick,
                          borderRadius: BorderRadius.circular(12),
                          child: const SizedBox(
                            height: 90,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_circle_outline,
                                    color: AppColors.textHint,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Kéo thả món ăn vào đây',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : InkWell(
                          onTap: () => onOpenDetail(recipe!),
                          borderRadius: BorderRadius.circular(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 76,
                                  height: 76,
                                  child: recipe!.imageUrl != null
                                      ? Image.network(
                                          recipe!.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                color: AppColors
                                                    .backgroundSecondary,
                                                child: const Icon(
                                                  Icons.restaurant,
                                                ),
                                              ),
                                        )
                                      : Container(
                                          color: AppColors.backgroundSecondary,
                                          child: const Icon(Icons.restaurant),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      recipe!.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${recipe!.totalTimeMinutes} phút • ${recipe!.difficulty}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: onClear,
                                icon: const Icon(
                                  Icons.close,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final RecipeSuggestion recipe;
  final VoidCallback onTap;

  const _SuggestionTile({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<RecipeSuggestion>(
      data: recipe,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.15),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            recipe.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: _buildTileContent()),
      child: _buildTileContent(),
    );
  }

  Widget _buildTileContent() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: recipe.imageUrl != null
                      ? Image.network(
                          recipe.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.backgroundSecondary,
                            child: const Icon(Icons.restaurant),
                          ),
                        )
                      : Container(
                          color: AppColors.backgroundSecondary,
                          child: const Icon(Icons.restaurant),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recipe.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveryCard extends StatelessWidget {
  final RecipeSuggestion recipe;
  final VoidCallback onTap;
  final VoidCallback onQuickAdd;

  const _DiscoveryCard({
    required this.recipe,
    required this.onTap,
    required this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<RecipeSuggestion>(
      data: recipe,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 190,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.2),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            recipe.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: _buildCard()),
      child: _buildCard(),
    );
  }

  Widget _buildCard() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.06),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: SizedBox(
                height: 128,
                width: double.infinity,
                child: recipe.imageUrl != null
                    ? Image.network(
                        recipe.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.backgroundSecondary,
                          child: const Icon(Icons.restaurant, size: 28),
                        ),
                      )
                    : Container(
                        color: AppColors.backgroundSecondary,
                        child: const Icon(Icons.restaurant, size: 28),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${recipe.totalTimeMinutes} phút',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: onQuickAdd,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 18,
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
}

class _DashedRoundedRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;

  const _DashedRoundedRectPainter({
    required this.color,
    this.radius = 16,
    this.strokeWidth = 1.4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()..addRRect(rrect);
    const dashLength = 7.0;
    const gapLength = 5.0;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
