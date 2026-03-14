import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final List<_ActivityItem> _activities = [
    _ActivityItem(
      icon: Icons.add_circle_outline,
      title: 'Đã thêm "Cà chua"',
      subtitle: 'Tủ lạnh · 500g · HSD: 20/03/2026',
      time: '2 giờ trước',
      color: AppColors.primary,
    ),
    _ActivityItem(
      icon: Icons.auto_awesome,
      title: 'Gợi ý công thức mới',
      subtitle: 'AI đề xuất: Canh chua cá lóc',
      time: '5 giờ trước',
      color: Color(0xFF7C4DFF),
    ),
    _ActivityItem(
      icon: Icons.warning_amber_rounded,
      title: 'Cảnh báo hết hạn',
      subtitle: '"Sữa tươi" sắp hết hạn trong 1 ngày',
      time: 'Hôm qua',
      color: AppColors.warning,
    ),
    _ActivityItem(
      icon: Icons.delete_outline,
      title: 'Đã xoá "Thịt heo"',
      subtitle: 'Tủ lạnh · Đã hết hạn',
      time: 'Hôm qua',
      color: AppColors.error,
    ),
    _ActivityItem(
      icon: Icons.add_circle_outline,
      title: 'Đã thêm "Trứng gà"',
      subtitle: 'Tủ lạnh · 10 quả · HSD: 25/03/2026',
      time: '2 ngày trước',
      color: AppColors.primary,
    ),
    _ActivityItem(
      icon: Icons.login_outlined,
      title: 'Đăng nhập tài khoản',
      subtitle: 'Windows · Chrome',
      time: '3 ngày trước',
      color: AppColors.textSecondary,
    ),
    _ActivityItem(
      icon: Icons.auto_awesome,
      title: 'Gợi ý công thức mới',
      subtitle: 'AI đề xuất: Bò xào rau củ',
      time: '3 ngày trước',
      color: Color(0xFF7C4DFF),
    ),
    _ActivityItem(
      icon: Icons.add_circle_outline,
      title: 'Đã thêm "Cà rốt"',
      subtitle: 'Tủ lạnh · 3 củ · HSD: 28/03/2026',
      time: '4 ngày trước',
      color: AppColors.primary,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: const Text(
          'Nhật ký hoạt động',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
            onPressed: _clearAll,
            tooltip: 'Xoá tất cả',
          ),
        ],
      ),
      body: _activities.isEmpty
          ? _buildEmpty()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _activities.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _buildActivityCard(_activities[i]),
            ),
    );
  }

  Widget _buildActivityCard(_ActivityItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.time,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text(
            'Chưa có hoạt động nào',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Các hoạt động trong ứng dụng\nsẽ xuất hiện tại đây',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xoá nhật ký',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Bạn có muốn xoá toàn bộ nhật ký hoạt động?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _activities.clear());
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color color;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });
}
