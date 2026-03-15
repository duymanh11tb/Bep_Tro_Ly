/// Một mục trong danh sách mua sắm
class ShoppingListItem {
  final String id;
  final String name;
  final String detail; // VD: "Khúc giữa - 500g", "1 bó nhỏ"
  final bool isChecked;
  final String? recipeId; // null = thuộc "Cần mua thêm"

  ShoppingListItem({
    required this.id,
    required this.name,
    required this.detail,
    this.isChecked = false,
    this.recipeId,
  });

  ShoppingListItem copyWith({
    String? id,
    String? name,
    String? detail,
    bool? isChecked,
    String? recipeId,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      name: name ?? this.name,
      detail: detail ?? this.detail,
      isChecked: isChecked ?? this.isChecked,
      recipeId: recipeId ?? this.recipeId,
    );
  }
}

/// Thông tin món ăn (cho section từ công thức)
class RecipeInfo {
  final String recipeId;
  final int servings;      // Số phần ăn
  final int cookTime;      // Phút
  final String difficulty; // easy, medium, hard -> Dễ, Trung bình, Khó
  final String? description; // Mô tả ngắn món ăn
  final String? tips;       // Mẹo chế biến

  RecipeInfo({
    required this.recipeId,
    this.servings = 4,
    this.cookTime = 0,
    this.difficulty = 'medium',
    this.description,
    this.tips,
  });

  String get difficultyLabel {
    switch (difficulty) {
      case 'easy': return 'Dễ';
      case 'hard': return 'Khó';
      default: return 'Trung bình';
    }
  }
}

/// Nhóm mục theo món ăn hoặc "Cần mua thêm"
class ShoppingListSection {
  final String title;
  final List<ShoppingListItem> items;
  final RecipeInfo? recipeInfo; // null = "Cần mua thêm"

  ShoppingListSection({
    required this.title,
    required this.items,
    this.recipeInfo,
  });

  bool get isRecipeSection => recipeInfo != null;
}
