import 'dart:convert';

import '../models/shopping_list_item.dart';
import 'api_service.dart';

class ShoppingService {
  static Future<List<ShoppingListSection>> getCurrentSections() async {
    try {
      final resp = await ApiService.get(
        '/api/shopping/current',
        withAuth: true,
      );
      if (resp.statusCode != 200) return [];

      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      final items = (data['items'] as List? ?? []);

      final Map<String, List<ShoppingListItem>> grouped = {};
      final Map<String, RecipeInfo?> recipeMeta = {};

      for (final raw in items) {
        final m = raw as Map<String, dynamic>;
        final recipeTitle = (m['from_recipe_title'] as String?)?.trim();
        final sectionKey = (recipeTitle != null && recipeTitle.isNotEmpty)
            ? recipeTitle
            : 'Can mua them';

        final quantity = (m['quantity'] as num?)?.toDouble();
        final unit = (m['unit'] as String?)?.trim();
        final detail = _buildDetail(quantity, unit, m['notes'] as String?);

        final item = ShoppingListItem(
          id: (m['item_id'] ?? '').toString(),
          name: (m['name_vi'] ?? m['name_en'] ?? 'San pham').toString(),
          detail: detail,
          isChecked: m['is_purchased'] == true,
          recipeId: m['from_recipe_id']?.toString(),
        );

        grouped.putIfAbsent(sectionKey, () => []);
        grouped[sectionKey]!.add(item);

        if (sectionKey != 'Can mua them') {
          recipeMeta[sectionKey] = RecipeInfo(
            recipeId: (m['from_recipe_id'] ?? 0).toString(),
            description: null,
            difficulty: 'medium',
            servings: 0,
            cookTime: 0,
          );
        } else {
          recipeMeta[sectionKey] = null;
        }
      }

      final sections = grouped.entries
          .map(
            (e) => ShoppingListSection(
              title: e.key,
              recipeInfo: recipeMeta[e.key],
              items: e.value,
            ),
          )
          .toList();

      sections.sort((a, b) {
        if (a.isRecipeSection == b.isRecipeSection) {
          return a.title.compareTo(b.title);
        }
        return a.isRecipeSection ? -1 : 1;
      });

      return sections;
    } catch (_) {
      return [];
    }
  }

  static Future<bool> setPurchased({
    required String itemId,
    required bool isPurchased,
  }) async {
    final parsed = int.tryParse(itemId);
    if (parsed == null) return false;

    try {
      final resp = await ApiService.put(
        '/api/shopping/items/$parsed/purchase',
        {'is_purchased': isPurchased},
        withAuth: true,
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static String _buildDetail(double? quantity, String? unit, String? notes) {
    final q = quantity != null ? _formatQuantity(quantity) : null;
    final u = (unit != null && unit.isNotEmpty) ? unit : null;
    final n = (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null;

    final parts = <String>[];
    if (q != null && u != null) {
      parts.add('$q $u');
    } else if (q != null) {
      parts.add(q);
    } else if (u != null) {
      parts.add(u);
    }
    if (n != null) parts.add(n);

    return parts.isEmpty ? 'Can mua' : parts.join(' - ');
  }

  static String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
