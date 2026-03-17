import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/recipe_suggestion.dart';

class RecipeDetailScreen extends StatelessWidget {
  final RecipeSuggestion recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  int _servingEstimate() {
    final estimated = (recipe.ingredientsUsed.length / 2).ceil() + 1;
    if (estimated < 2) return 2;
    if (estimated > 6) return 6;
    return estimated;
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: _buildHeaderImage(),
                ),
              ),
              const SizedBox(height: 14),
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
                'Nguyên liệu',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
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
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10D93A),
                    foregroundColor: Colors.black,
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
                  child: const Text('Bắt đầu nấu'),
                ),
              ),
            ],
          ),
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
    final ingredients = <String>[
      ...recipe.ingredientsUsed,
      ...recipe.ingredientsMissing,
    ];

    if (ingredients.isEmpty) {
      return [
        const Text(
          'Chưa có danh sách nguyên liệu.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ];
    }

    return ingredients.asMap().entries.map((entry) {
      final i = entry.key;
      final text = entry.value;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: i == ingredients.length - 1
                  ? Colors.transparent
                  : const Color(0xFFE5E7EB),
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_box_outline_blank,
              size: 20,
              color: AppColors.textHint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
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
    final secondary = RecipeSuggestion.fallbackImageForRecipe(recipe);

    if (primary == null || primary.isEmpty) {
      return Image.network(
        secondary,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImageFallback(recipe.name),
      );
    }

    return Image.network(
      primary,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Image.network(
          secondary,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildImageFallback(recipe.name),
        );
      },
    );
  }
}
