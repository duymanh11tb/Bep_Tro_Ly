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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 260,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textPrimary,
              title: const Text('Chi tiết công thức'),
              flexibleSpace: FlexibleSpaceBar(background: _buildHeaderImage()),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recipe.description,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildInfoPill(
                          Icons.access_time_filled,
                          recipe.cookTimeText,
                        ),
                        const SizedBox(width: 10),
                        _buildInfoPill(
                          Icons.restaurant,
                          '${_servingEstimate()} người',
                        ),
                        const SizedBox(width: 10),
                        _buildInfoPill(Icons.bolt, recipe.difficulty),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _buildSectionTitle('Nguyên liệu đang có'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: recipe.ingredientsUsed.map((item) {
                        return _buildTag(item, const Color(0xFFB7F5C7));
                      }).toList(),
                    ),
                    if (recipe.ingredientsMissing.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _buildSectionTitle('Nguyên liệu còn thiếu'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: recipe.ingredientsMissing.map((item) {
                          return _buildTag(item, const Color(0xFFFEE2E2));
                        }).toList(),
                      ),
                    ],
                    if (recipe.instructions.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _buildSectionTitle('Cách làm'),
                      const SizedBox(height: 8),
                      ...recipe.instructions.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${entry.key + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    if (recipe.tips != null &&
                        recipe.tips!.trim().isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _buildSectionTitle('Mẹo nấu'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          recipe.tips!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTag(String text, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
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
