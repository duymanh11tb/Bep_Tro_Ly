import 'package:flutter/material.dart';
import '../../repositories/recipe_repository.dart';
import '../../models/recipe_suggestion.dart';
import 'recipe_detail_screen.dart';

class RecipeSuggestionScreen extends StatefulWidget {
  final List<String> ingredients;
  final List<String>? expiringIngredients;
  
  const RecipeSuggestionScreen({
    Key? key,
    required this.ingredients,
    this.expiringIngredients,
  }) : super(key: key);
  
  @override
  State<RecipeSuggestionScreen> createState() => _RecipeSuggestionScreenState();
}

class _RecipeSuggestionScreenState extends State<RecipeSuggestionScreen> {
  List<RecipeSuggestion> _recipes = [];
  bool _isLoading = true;
  String? _error;
  
  // Cache key dựa trên nguyên liệu
  String get _cacheKey {
    final ingredientsKey = widget.ingredients.join(',');
    final expiringKey = widget.expiringIngredients?.join(',') ?? '';
    return 'recipes_${ingredientsKey}_$expiringKey';
  }
  
  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }
  
  Future<void> _loadSuggestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Thử lấy từ cache trước
      final cached = await RecipeRepository.getCachedSuggestions(_cacheKey);
      if (cached.isNotEmpty) {
        setState(() {
          _recipes = cached;
          _isLoading = false;
        });
        return;
      }
      
      // Gọi API mới
      final suggestions = await RecipeRepository.getSuggestions(
        ingredients: widget.ingredients,
        expiringIngredients: widget.expiringIngredients,
        limit: 5,
      );
      
      // Cache kết quả
      if (suggestions.isNotEmpty) {
        await RecipeRepository.cacheSuggestions(suggestions, _cacheKey);
      }
      
      setState(() {
        _recipes = suggestions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gợi ý món ăn từ Gemini'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSuggestions,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Lỗi: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSuggestions,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    
    if (_recipes.isEmpty) {
      return const Center(
        child: Text('Không tìm thấy gợi ý nào. Hãy thêm nguyên liệu khác!'),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recipes.length,
      itemBuilder: (context, index) {
        final recipe = _recipes[index];
        return _buildRecipeCard(recipe);
      },
    );
  }
  
  Widget _buildRecipeCard(RecipeSuggestion recipe) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ảnh
          if (recipe.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                recipe.imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported, size: 48),
                ),
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tên và độ phù hợp
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        recipe.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getMatchColor(recipe.matchPercentage),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${recipe.matchPercentage}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Badge sắp hết hạn
                if (recipe.ingredientsExpiringCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Dùng ${recipe.ingredientsExpiringCount} nguyên liệu sắp hết',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 8),
                
                // Mô tả
                Text(
                  recipe.description,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                
                // Thông tin thời gian và độ khó
                Row(
                  children: [
                    _buildInfoChip(
                      icon: Icons.timer,
                      label: recipe.cookTimeText,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      icon: Icons.fitness_center,
                      label: _getDifficultyText(recipe.difficulty),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Nút xem chi tiết
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _showRecipeDetail(recipe);
                    },
                    child: const Text('Xem chi tiết'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
  
  Color _getMatchColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }
  
  String _getDifficultyText(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 'Dễ';
      case 'medium':
        return 'Trung bình';
      case 'hard':
        return 'Khó';
      default:
        return 'Dễ';
    }
  }
  
  void _showRecipeDetail(RecipeSuggestion recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
    );
  }
}
