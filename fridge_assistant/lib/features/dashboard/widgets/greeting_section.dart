import 'package:fridge_assistant/core/localization/app_material.dart';
import '../../../core/theme/app_colors.dart';

class GreetingSection extends StatelessWidget {
  final String userName;
  final String? statusMessage;
  final String? avatarUrl;
  final VoidCallback? onRecipeSuggestTap;

  const GreetingSection({
    super.key,
    required this.userName,
    this.statusMessage,
    this.avatarUrl,
    this.onRecipeSuggestTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryLight,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                    ),
                  )
                : _buildDefaultAvatar(),
          ),
          const SizedBox(width: 14),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, $userName 👋',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  statusMessage ?? 'Tủ lạnh đang cần sự chú ý của bạn',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Recipe suggestion button
          if (onRecipeSuggestTap != null)
            ElevatedButton.icon(
              onPressed: onRecipeSuggestTap,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text(
                'GỢI Ý',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 2,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return const Center(
      child: Icon(Icons.person, color: AppColors.primary, size: 28),
    );
  }
}
