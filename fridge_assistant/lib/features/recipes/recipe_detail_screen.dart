import 'package:fridge_assistant/core/localization/app_material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/recipe_suggestion.dart';
import '../../models/shopping_list_item.dart';
import '../../services/local_notification_service.dart';
import '../../services/pantry_service.dart';
import '../../services/shopping_service.dart';
import '../../services/activity_log_service.dart';
import '../../services/fridge_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../shopping/cooking_detail_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final RecipeSuggestion recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _isLoadingPantry = true;
  bool _isAddingMissing = false;
  bool _hasShownMissingSuggestionNotif = false;
  List<_IngredientState> _ingredients = const [];
  final Set<String> _checkedIngredientKeys = <String>{};

  RecipeSuggestion get recipe => widget.recipe;

  @override
  void initState() {
    super.initState();
    _loadIngredientState();
  }

  Future<void> _loadIngredientState() async {
    setState(() => _isLoadingPantry = true);

    final pantryItems = await PantryService.getItems();
    if (!mounted) return;

    final states = _buildIngredientState(pantryItems);

    setState(() {
      _ingredients = states;
      _checkedIngredientKeys
        ..clear()
        ..addAll(states.where((e) => e.isAvailable).map((e) => e.key));
      _isLoadingPantry = false;
    });

    final missingLabels = states
        .where((e) => !e.isAvailable)
        .map((e) => e.label)
        .toList();
    if (!_hasShownMissingSuggestionNotif && missingLabels.isNotEmpty) {
      _hasShownMissingSuggestionNotif = true;
      await LocalNotificationService.showMissingIngredientsSuggestion(
        recipeName: recipe.name,
        missingIngredients: missingLabels,
      );
    }
  }

  int _servingEstimate() {
    final estimated = (recipe.ingredientsUsed.length / 2).ceil() + 1;
    if (estimated < 2) return 2;
    if (estimated > 6) return 6;
    return estimated;
  }

  Future<void> _handleFeedback(String feedback) async {
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

  String _difficultyText() {
    switch (recipe.difficulty.toLowerCase()) {
      case 'easy':
      case 'de':
        return 'Dễ';
      case 'medium':
      case 'trung binh':
      case 'trung bình':
        return 'Trung bình';
      case 'hard':
      case 'kho':
      case 'khó':
        return 'Khó';
      default:
        return recipe.difficulty;
    }
  }

  List<_IngredientState> _buildIngredientState(List<PantryItem> pantryItems) {
    final normalizedPantry = pantryItems
        .map((e) => _normalizeText(e.name))
        .where((e) => e.isNotEmpty)
        .toList();

    final merged = <String>[
      ...recipe.ingredientsUsed,
      ...recipe.ingredientsMissing,
    ];
    final unique = <String>[];
    final seen = <String>{};
    for (final raw in merged) {
      final text = raw.trim();
      if (text.isEmpty) continue;
      final key = _normalizeText(text);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      unique.add(text);
    }

    return unique.map((ingredient) {
      final normalizedIngredient = _normalizeText(_ingredientCore(ingredient));
      final isAvailable = normalizedPantry.any(
        (pantryName) => _isLikelyMatch(normalizedIngredient, pantryName),
      );
      return _IngredientState(
        key: normalizedIngredient.isEmpty
            ? _normalizeText(ingredient)
            : normalizedIngredient,
        label: ingredient,
        isAvailable: isAvailable,
      );
    }).toList();
  }

  String _ingredientCore(String input) {
    final text = input.trim();
    if (text.isEmpty) return text;
    final parts = text.split(RegExp(r'[,;(\-]'));
    return parts.first.trim();
  }

  String _normalizeText(String input) {
    var text = input.toLowerCase().trim();
    const vietnameseMap = {
      'à': 'a',
      'á': 'a',
      'ạ': 'a',
      'ả': 'a',
      'ã': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ậ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ặ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'è': 'e',
      'é': 'e',
      'ẹ': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ệ': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ì': 'i',
      'í': 'i',
      'ị': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ò': 'o',
      'ó': 'o',
      'ọ': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ộ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ợ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ụ': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ự': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỵ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'đ': 'd',
    };

    vietnameseMap.forEach((key, value) {
      text = text.replaceAll(key, value);
    });

    return text
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isLikelyMatch(String ingredient, String pantryName) {
    if (ingredient.isEmpty || pantryName.isEmpty) return false;
    if (ingredient == pantryName) return true;

    final ingredientTokens = ingredient
        .split(' ')
        .where((t) => t.length >= 3)
        .toList();
    final pantryTokens = pantryName
        .split(' ')
        .where((t) => t.length >= 3)
        .toList();

    final overlap = ingredientTokens.where(pantryTokens.contains).length;
    if (overlap >= 2) return true;

    if (ingredient.length >= 4 && pantryName.contains(ingredient)) return true;
    if (pantryName.length >= 4 && ingredient.contains(pantryName)) return true;

    return false;
  }

  List<_IngredientState> get _availableIngredients =>
      _ingredients.where((e) => e.isAvailable).toList();

  List<_IngredientState> get _missingIngredients =>
      _ingredients.where((e) => !e.isAvailable).toList();

  bool get _allAvailableChecked {
    final available = _availableIngredients;
    if (available.isEmpty) return false;
    return available.every((e) => _checkedIngredientKeys.contains(e.key));
  }

  bool get _canStartCooking =>
      _missingIngredients.isEmpty && _allAvailableChecked && !_isLoadingPantry;

  List<String> _buildSteps() {
    final raw = recipe.instructions.where((e) => e.trim().isNotEmpty).toList();
    if (raw.isNotEmpty) return raw;
    return const [
      'Sơ chế nguyên liệu: rửa sạch, cắt và chuẩn bị gia vị.',
      'Bắt đầu nấu: cho nguyên liệu chính vào nồi/chảo theo thứ tự phù hợp.',
      'Nêm nếm, hoàn thiện món và trình bày ra đĩa.',
    ];
  }

  ShoppingListSection _buildCookingSection() {
    final items = _availableIngredients
        .map(
          (e) => ShoppingListItem(
            id: '${recipe.id}_${e.key}',
            name: e.label,
            detail: 'Đã chuẩn bị',
            recipeId: recipe.id,
            isChecked: true,
          ),
        )
        .toList();

    return ShoppingListSection(
      title: recipe.name,
      recipeInfo: RecipeInfo(
        recipeId: recipe.id,
        servings: _servingEstimate(),
        cookTime: recipe.cookTimeMinutes > 0 ? recipe.cookTimeMinutes : 20,
        prepTime: recipe.prepTimeMinutes,
        difficulty: recipe.difficulty.toLowerCase(),
        description: recipe.description,
        tips: recipe.tips,
        imageUrl: recipe.imageUrl,
        steps: _buildSteps(),
      ),
      items: items,
    );
  }

  Future<void> _addMissingToShoppingList() async {
    if (_missingIngredients.isEmpty || _isAddingMissing) return;
    setState(() => _isAddingMissing = true);

    var successCount = 0;
    for (final missing in _missingIngredients) {
      final success = await ShoppingService.addItem(
        name: missing.label,
        notes: 'Thiếu cho món ${recipe.name}',
      );
      if (success) successCount += 1;
    }

    if (!mounted) return;

    setState(() => _isAddingMissing = false);

    final failCount = _missingIngredients.length - successCount;
    final message = failCount == 0
        ? 'Đã thêm ${_missingIngredients.length} nguyên liệu thiếu vào danh sách mua sắm.'
        : 'Đã thêm $successCount món. Còn $failCount món chưa thêm được, vui lòng thử lại.';

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: failCount == 0
            ? SnackBarAction(label: 'Mở đi chợ', onPressed: _openShoppingTab)
            : null,
      ),
    );

    if (successCount > 0) {
      await LocalNotificationService.showMissingIngredientsSuggestion(
        recipeName: recipe.name,
        missingIngredients: _missingIngredients.map((e) => e.label).toList(),
      );
    }
  }

  void _openShoppingTab() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const DashboardScreen(initialTabIndex: 3),
      ),
      (route) => false,
    );
  }

  void _toggleIngredient(_IngredientState ingredient, bool? value) {
    if (!ingredient.isAvailable) return;
    setState(() {
      if (value == true) {
        _checkedIngredientKeys.add(ingredient.key);
      } else {
        _checkedIngredientKeys.remove(ingredient.key);
      }
    });
  }

  void _startCooking() {
    if (!_canStartCooking) {
      final missingCount = _missingIngredients.length;
      final uncheckedCount =
          _availableIngredients.length -
          _availableIngredients
              .where((e) => _checkedIngredientKeys.contains(e.key))
              .length;

      final message = missingCount > 0
          ? 'Bạn còn thiếu $missingCount nguyên liệu. Hãy mua bổ sung trước khi nấu.'
          : 'Bạn còn $uncheckedCount nguyên liệu chưa tích xác nhận chuẩn bị.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    // Log activity
    _logCookingActivity();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CookingDetailScreen(section: _buildCookingSection()),
      ),
    );
  }

  Future<void> _logCookingActivity() async {
    try {
      final fridgeId = await FridgeService.getActiveFridgeId();
      await ActivityLogService.logCooking(
        fridgeId,
        recipe.name,
        recipeId: int.tryParse(recipe.id),
      );
    } catch (e) {
      debugPrint('Error logging cooking: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        title: Text(
          recipe.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => _handleFeedback('liked'),
            icon: Icon(
              recipe.status == 'liked' ? Icons.favorite : Icons.favorite_border,
              color: recipe.status == 'liked' ? Colors.red : null,
            ),
          ),
          IconButton(
            onPressed: () => _handleFeedback('disliked'),
            icon: Icon(
              recipe.status == 'disliked'
                  ? Icons.thumb_down
                  : Icons.thumb_down_outlined,
              color: recipe.status == 'disliked' ? Colors.orange : null,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: 190,
                      width: double.infinity,
                      child: _buildHeaderImage(),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.flash_on,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tương thích ${recipe.matchPercentage}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (recipe.cuisines.isNotEmpty || recipe.dishTypes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...recipe.cuisines.map(
                        (c) => _buildMetadataBadge(c, const Color(0xFFFFE0B2)),
                      ),
                      ...recipe.dishTypes.map(
                        (t) => _buildMetadataBadge(t, const Color(0xFFE1F5FE)),
                      ),
                    ],
                  ),
                ),
              Text(
                recipe.description,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.4,
                children: [
                  _buildMetricCard(
                    'Chuẩn bị',
                    recipe.prepTimeMinutes > 0
                        ? '${recipe.prepTimeMinutes} Phút'
                        : '15 Phút',
                  ),
                  _buildMetricCard(
                    'Nấu',
                    recipe.cookTimeMinutes > 0
                        ? '${recipe.cookTimeMinutes} Phút'
                        : '30 Phút',
                  ),
                  _buildMetricCard('Khẩu phần', '${_servingEstimate()} Người'),
                  _buildMetricCard('Độ khó', _difficultyText()),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Cách nấu (Công thức)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildSteps().asMap().entries.map((entry) {
                    final i = entry.key;
                    final step = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(fontSize: 10, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              step,
                              style: const TextStyle(fontSize: 15, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Nguyên liệu',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (_isLoadingPantry)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(color: AppColors.primary),
                ),
              if (!_isLoadingPantry && _missingIngredients.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCC80)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bạn đang thiếu ${_missingIngredients.length} nguyên liệu cho món này.',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8A4B08),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _isAddingMissing
                              ? null
                              : _addMissingToShoppingList,
                          icon: _isAddingMissing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_shopping_cart),
                          label: const Text('Thêm vào danh sách mua'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8A4B08),
                            side: const BorderSide(color: Color(0xFFFFB74D)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: _buildIngredientRows()),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startCooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canStartCooking
                        ? const Color(0xFF10D93A)
                        : const Color(0xFFB9EBC4),
                    foregroundColor: _canStartCooking
                        ? Colors.black
                        : const Color(0xFF4B5563),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(
                    _canStartCooking
                        ? 'Bắt đầu nấu'
                        : 'Chuẩn bị đủ nguyên liệu để nấu',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildIngredientRows() {
    if (_ingredients.isEmpty && !_isLoadingPantry) {
      return [
        const Text(
          'Chưa có danh sách nguyên liệu.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ];
    }

    return _ingredients.asMap().entries.map((entry) {
      final i = entry.key;
      final ingredient = entry.value;
      final isChecked = _checkedIngredientKeys.contains(ingredient.key);
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: i == _ingredients.length - 1
                  ? Colors.transparent
                  : const Color(0xFFE5E7EB),
            ),
          ),
        ),
        child: Row(
          children: [
            ingredient.isAvailable
                ? Checkbox(
                    value: isChecked,
                    activeColor: AppColors.primary,
                    onChanged: (value) => _toggleIngredient(ingredient, value),
                  )
                : const Icon(
                    Icons.remove_shopping_cart_outlined,
                    size: 20,
                    color: Color(0xFFEF6C00),
                  ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ingredient.label,
                style: TextStyle(
                  fontSize: 16,
                  color: ingredient.isAvailable
                      ? AppColors.textPrimary
                      : const Color(0xFF9A3412),
                ),
              ),
            ),
            if (!ingredient.isAvailable)
              const Text(
                'Cần mua',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF6C00),
                ),
              ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildImageFallback(String recipeName) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDE68A), Color(0xFFFCA5A5)],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          recipeName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderImage() {
    final primary = recipe.imageUrl;
    if (primary == null || primary.isEmpty) {
      return _buildImageFallback(recipe.name);
    }

    return Image.network(
      primary,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildImageFallback(recipe.name),
    );
  }
}

class _IngredientState {
  final String key;
  final String label;
  final bool isAvailable;

  const _IngredientState({
    required this.key,
    required this.label,
    required this.isAvailable,
  });
}
