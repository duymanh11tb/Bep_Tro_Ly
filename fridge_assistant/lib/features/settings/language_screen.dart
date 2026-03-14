import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLanguage = 'vi';

  final List<_Language> _languages = const [
    _Language(code: 'vi', name: 'Tiếng Việt', flag: '🇻🇳', native: 'Vietnamese'),
    _Language(code: 'en', name: 'English', flag: '🇺🇸', native: 'English'),
    _Language(code: 'ja', name: '日本語', flag: '🇯🇵', native: 'Japanese'),
    _Language(code: 'ko', name: '한국어', flag: '🇰🇷', native: 'Korean'),
    _Language(code: 'zh', name: '中文', flag: '🇨🇳', native: 'Chinese'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Ngôn ngữ',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _languages.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, i) {
          final lang = _languages[i];
          final isSelected = _selectedLanguage == lang.code;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            leading: Text(
              lang.flag,
              style: const TextStyle(fontSize: 28),
            ),
            title: Text(
              lang.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              lang.native,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: AppColors.primary, size: 22)
                : const Icon(Icons.circle_outlined, color: AppColors.divider, size: 22),
            onTap: () {
              setState(() => _selectedLanguage = lang.code);
              Future.delayed(const Duration(milliseconds: 250), () {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Đã chọn ngôn ngữ: ${lang.name}'),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.pop(context);
                }
              });
            },
          );
        },
      ),
    );
  }
}

class _Language {
  final String code;
  final String name;
  final String flag;
  final String native;

  const _Language({
    required this.code,
    required this.name,
    required this.flag,
    required this.native,
  });
}
