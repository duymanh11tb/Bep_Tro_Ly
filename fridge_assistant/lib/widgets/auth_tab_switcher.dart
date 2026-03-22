import 'package:fridge_assistant/core/localization/app_material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Tab switcher component cho Login/Register toggle
class AuthTabSwitcher extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabChanged;
  final List<String> tabs;

  const AuthTabSwitcher({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
    this.tabs = const ['Đăng nhập', 'Đăng ký'],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          tabs.length,
          (index) => _buildTab(index),
        ),
      ),
    );
  }

  Widget _buildTab(int index) {
    final isSelected = selectedIndex == index;
    
    return GestureDetector(
      onTap: () => onTabChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.background : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          tabs[index],
          style: isSelected ? AppTextStyles.tabActive : AppTextStyles.tabInactive,
        ),
      ),
    );
  }
}
