import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class DashboardHeader extends StatelessWidget {
  final String? avatarUrl;
  final VoidCallback? onNotificationTap;

  const DashboardHeader({
    super.key,
    this.avatarUrl,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(76, 175, 80, 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
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
          const SizedBox(width: 12),
          
          // Title
          const Text(
            'Bếp trợ lí',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          
          const Spacer(),
          
          // Notification Bell
          GestureDetector(
            onTap: onNotificationTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.notifications_outlined,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                  ),
                  // Notification badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return const Center(
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}
