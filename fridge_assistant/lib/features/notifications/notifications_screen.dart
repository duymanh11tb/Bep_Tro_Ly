import 'package:fridge_assistant/core/localization/app_material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../recipes/recipe_recommendations_screen.dart';
import '../shopping/shopping_list_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final results = await _notificationService.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = results;
        _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRespond(NotificationModel notification, bool accept) async {
    setState(() => _isLoading = true);
    final result = await _notificationService.respondToInvitation(notification.notificationId, accept);
    
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'])),
      );
      if (result['success']) {
        _loadNotifications();
      }
    }
  }

  Future<void> _handleMarkRead(NotificationModel notification) async {
    if (notification.isRead) return;
    
    // Đừng tự động đánh dấu đã đọc cho lời mời tủ lạnh khi chỉ mới nhấn vào thẻ
    // Điều này giúp giữ lại nút Chấp nhận/Từ chối cho đến khi người dùng quyết định.
    if (notification.type == 'fridge_invitation') return;

    await _notificationService.markAsRead(notification.notificationId);
    _loadNotifications();
  }

  Future<void> _markAllAsRead() async {
    final unread = _notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;
    setState(() => _isLoading = true);
    await Future.wait(unread.map((n) => _notificationService.markAsRead(n.notificationId)));
    await _loadNotifications();
  }

  List<NotificationModel> get _filteredNotifications {
    switch (_selectedFilter) {
      case 'Chưa đọc':
        return _notifications.where((n) => !n.isRead).toList();
      case 'Hạn sử dụng':
        return _notifications.where((n) => n.type == 'expiry_alert').toList();
      case 'Gợi ý':
        return _notifications.where((n) => n.type == 'recipe_suggestion').toList();
      default:
        return _notifications;
    }
  }

  Map<String, List<NotificationModel>> _groupNotificationsByDate(List<NotificationModel> list) {
    final Map<String, List<NotificationModel>> grouped = {
      'HÔM NAY': [],
      'HÔM QUA': [],
      'TUẦN TRƯỚC': [],
      'CŨ HƠN': [],
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));

    for (var n in list) {
      final date = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      if (date.isAtSameMomentAs(today)) {
        grouped['HÔM NAY']!.add(n);
      } else if (date.isAtSameMomentAs(yesterday)) {
        grouped['HÔM QUA']!.add(n);
      } else if (date.isAfter(lastWeek) || date.isAtSameMomentAs(lastWeek)) {
        grouped['TUẦN TRƯỚC']!.add(n);
      } else {
        grouped['CŨ HƠN']!.add(n);
      }
    }

    grouped.removeWhere((key, value) => value.isEmpty);
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Thông báo',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.black38),
            onPressed: unreadCount > 0 ? _markAllAsRead : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                _buildFilterChips(unreadCount),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadNotifications,
                    color: AppColors.primary,
                    child: _notifications.isEmpty
                        ? _buildEmptyState()
                        : _buildNotificationList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChips(int unreadCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChip('Tất cả'),
            const SizedBox(width: 8),
            _buildChip('Chưa đọc', badgeCount: unreadCount),
            const SizedBox(width: 8),
            _buildChip('Hạn sử dụng'),
            const SizedBox(width: 8),
            _buildChip('Gợi ý'),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, {int? badgeCount}) {
    final isSelected = _selectedFilter == (label == 'Chưa đọc' ? 'Chưa đọc' : label);
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label == 'Chưa đọc' ? 'Chưa đọc' : label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF063A27) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF063A27) : const Color(0xFFE0E0E0),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Chưa có thông báo nào',
            style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList() {
    final grouped = _groupNotificationsByDate(_filteredNotifications);
    if (grouped.isEmpty) {
      return const Center(
        child: Text(
          'Không có thông báo phù hợp',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final keys = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: keys.length + 1, // +1 for footer
      itemBuilder: (context, index) {
        if (index == keys.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Đã hiển thị tất cả thông báo',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              ),
            ),
          );
        }

        final groupKey = keys[index];
        final items = grouped[groupKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 12),
              child: Text(
                groupKey,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9CA3AF),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...items.map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildNotificationCard(n),
                )),
          ],
        );
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    Color accentColor;
    IconData iconData;
    String buttonText = '';

    switch (notification.type) {
      case 'expiry_alert':
        accentColor = const Color(0xFFEF4444);
        iconData = Icons.warning_amber_rounded;
        buttonText = 'Xem công thức';
        break;
      case 'recipe_suggestion':
        accentColor = const Color(0xFF10B981);
        iconData = Icons.auto_awesome;
        break;
      case 'shopping_alert':
        accentColor = const Color(0xFF3B82F6);
        iconData = Icons.shopping_cart_outlined;
        buttonText = 'Thêm vào giỏ';
        break;
      case 'fridge_invitation':
        accentColor = AppColors.primary;
        iconData = Icons.person_add_alt_1_outlined;
        break;
      case 'system':
      case 'achievement':
        accentColor = const Color(0xFFF59E0B);
        iconData = Icons.celebration_outlined;
        break;
      default:
        accentColor = const Color(0xFF6B7280);
        iconData = Icons.notifications_none;
    }

    return GestureDetector(
      onTap: () => _handleMarkRead(notification),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(color: accentColor, width: 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
                              fontSize: 15,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        Text(
                          _formatTime(notification.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4B5563),
                        height: 1.4,
                      ),
                    ),
                    if (notification.type == 'fridge_invitation' && !notification.isRead) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _handleRespond(notification, false),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                foregroundColor: Colors.red,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: const Text('Từ chối', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _handleRespond(notification, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: const Text('Chấp nhận', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ] else if (buttonText.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () {
                          if (buttonText == 'Xem công thức') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RecipeRecommendationsScreen(),
                              ),
                            ).then((_) => _loadNotifications());
                          } else if (buttonText == 'Thêm vào giỏ') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ShoppingListScreen(),
                              ),
                            ).then((_) => _loadNotifications());
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            buttonText,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (notification.type == 'recipe_suggestion' || notification.type == 'achievement') ...[
                const Padding(
                  padding: EdgeInsets.only(top: 10, left: 8),
                  child: Icon(Icons.chevron_right, color: Color(0xFFD1D5DB), size: 20),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${time.day}/${time.month}';
  }
}
