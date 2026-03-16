import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/shopping_list_item.dart';

/// Màn hình Công thức nấu ăn chi tiết - Phiên bản nâng cấp
class CookingDetailScreen extends StatefulWidget {
  final ShoppingListSection section;

  const CookingDetailScreen({super.key, required this.section});

  @override
  State<CookingDetailScreen> createState() => _CookingDetailScreenState();
}

class _CookingDetailScreenState extends State<CookingDetailScreen> {
  late List<bool> _stepCompleted;
  
  @override
  void initState() {
    super.initState();
    final stepsCount = widget.section.recipeInfo?.steps?.length ?? 3;
    _stepCompleted = List.generate(stepsCount, (index) => false);
  }

  double get _progress {
    if (_stepCompleted.isEmpty) return 0;
    final completedCount = _stepCompleted.where((c) => c).length;
    return completedCount / _stepCompleted.length;
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.section.recipeInfo;
    final hasRecipeInfo = info != null;
    final steps = info?.steps ?? [
      'Sơ chế nguyên liệu sạch sẽ.',
      'Tiến hành nấu và nêm nếm gia vị vừa ăn.',
      'Trình bày ra đĩa và thưởng thức.'
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ──── App Bar với Ảnh & Tiến độ ────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_progress > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          )
                        ],
                      ),
                      child: Text(
                        '${(_progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.section.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  shadows: [Shadow(color: Colors.black, blurRadius: 12)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  info?.imageUrl != null && info!.imageUrl!.isNotEmpty
                      ? Image.network(
                          info.imageUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, Color(0xFFFF9800)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.restaurant_menu,
                              size: 80,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                  // Overlay gradient cho text dễ đọc hơn
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ──── Nội dung Chi tiết ────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ──── Thanh tiến trình ────
                  if (_stepCompleted.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ──── Thông tin nhanh ────
                  if (hasRecipeInfo)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat('Phần ăn', '${info.servings}', Icons.people_outline),
                          _buildStat('Nấu', '${info.cookTime}\'', Icons.timer_outlined),
                          _buildStat('Độ khó', info.difficultyLabel, Icons.workspace_premium_outlined),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // ──── Nguyên liệu ────
                  const Text(
                    'Nguyên liệu cần chuẩn bị',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: widget.section.items.map((item) => _buildIngredientItem(item)).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ──── Mẹo chế biến ────
                  if (info?.tips != null && info!.tips!.isNotEmpty) ...[
                    const Text(
                      'Bí quyết từ Bếp Trợ Lý',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTipsCard(info.tips!),
                    const SizedBox(height: 24),
                  ],

                  // ──── Các bước thực hiện ────
                  const Text(
                    'Các bước thực hiện',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(steps.length, (index) => _buildStepItem(index, steps[index])),
                  
                  const SizedBox(height: 40),
                  
                  // ──── Nút hoàn thành ────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_progress < 1.0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Hãy hoàn thành tất cả các bước nhé!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _progress == 1.0 ? AppColors.primary : Colors.grey[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _progress == 1.0 ? 'Hoàn thành món ăn ✨' : 'Đang thực hiện...',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientItem(ShoppingListItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.circle, color: AppColors.primary, size: 6),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            item.detail,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9C4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF5D4037),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(int index, String content) {
    final isCompleted = _stepCompleted[index];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          setState(() {
            _stepCompleted[index] = !_stepCompleted[index];
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCompleted ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCompleted ? AppColors.primary.withValues(alpha: 0.3) : AppColors.divider.withValues(alpha: 0.5),
              width: isCompleted ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted 
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  content,
                  style: TextStyle(
                    fontSize: 15,
                    color: isCompleted ? AppColors.textHint : AppColors.textPrimary,
                    height: 1.5,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
