import 'package:fridge_assistant/core/localization/app_material.dart';
import '../../../core/theme/app_colors.dart';

class DietaryPreferencesSection extends StatefulWidget {
  final String selectedDiet;
  final List<String> selectedAllergies;
  final List<String> selectedCuisines; // Thêm cuisines
  final Function(String) onDietChanged;
  final Function(String) onAddAllergy;
  final Function(String) onRemoveAllergy;
  final Function(List<String>) onCuisinesChanged; // Thêm callback

  const DietaryPreferencesSection({
    super.key,
    required this.selectedDiet,
    required this.selectedAllergies,
    required this.selectedCuisines,
    required this.onDietChanged,
    required this.onAddAllergy,
    required this.onRemoveAllergy,
    required this.onCuisinesChanged,
  });

  @override
  State<DietaryPreferencesSection> createState() => _DietaryPreferencesSectionState();
}

class _DietaryPreferencesSectionState extends State<DietaryPreferencesSection> {
  final List<String> _dietModes = ['Bình thường', 'Ăn chay', 'Eat Clean'];
  final List<String> _commonAllergies = ['Đậu phộng', 'Sữa & chế phẩm', 'Hải sản'];
  final List<String> _cuisineOptions = ['Việt Nam', 'Hàn Quốc', 'Nhật Bản', 'Trung Quốc', 'Món Âu'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Sở thích ăn uống', // Đổi tên cho đồng nhất
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
            ],
          ),
          const Text(
            'Hệ thống sẽ gợi ý món ăn dựa trên các thông tin này.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          
          // Diet Mode
          const Text(
            'Chế độ ăn',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _dietModes.map((mode) {
              final isSelected = widget.selectedDiet == mode;
              return ChoiceChip(
                label: Text(mode),
                selected: isSelected,
                onSelected: (_) => widget.onDietChanged(mode),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : Colors.grey[300]!,
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 20),
          
          // Allergies
          const Text(
            'Dị ứng / Nguyên liệu tránh',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...widget.selectedAllergies.map((allergy) => Chip(
                label: Text(allergy),
                onDeleted: () => widget.onRemoveAllergy(allergy),
                deleteIcon: const Icon(Icons.close, size: 14),
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                side: const BorderSide(color: AppColors.primary),
                labelStyle: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500),
              )),
              
              ..._commonAllergies.where((a) => !widget.selectedAllergies.contains(a)).map((allergy) => ActionChip(
                label: Text(allergy),
                onPressed: () => widget.onAddAllergy(allergy),
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey[300]!),
                labelStyle: const TextStyle(fontSize: 13),
              )),
            ],
          ),

          const SizedBox(height: 20),

          // Cuisines
          const Text(
            'Ẩm thực yêu thích',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cuisineOptions.map((cuisine) {
              final isSelected = widget.selectedCuisines.contains(cuisine);
              return FilterChip(
                label: Text(cuisine),
                selected: isSelected,
                onSelected: (val) {
                  List<String> newList = List.from(widget.selectedCuisines);
                  if (val) {
                    newList.add(cuisine);
                  } else {
                    newList.remove(cuisine);
                  }
                  widget.onCuisinesChanged(newList);
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                checkmarkColor: AppColors.primary,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
