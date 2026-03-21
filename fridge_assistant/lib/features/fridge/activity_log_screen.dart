import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/activity_log_model.dart';
import '../../services/activity_log_service.dart';
import '../../core/theme/app_colors.dart';

class ActivityLogScreen extends StatefulWidget {
  final int fridgeId;

  const ActivityLogScreen({super.key, required this.fridgeId});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final ActivityLogService _service = ActivityLogService();
  bool _isLoading = true;
  List<ActivityLogModel> _allLogs = [];
  String _currentFilter = 'all';

  final List<Map<String, String>> _filters = [
    {'label': 'Tất cả', 'value': 'all'},
    {'label': 'Thêm vào', 'value': 'add_item'},
    {'label': 'Lấy ra', 'value': 'use_item'},
    {'label': 'Nấu ăn', 'value': 'cook_recipe'},
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _service.getFridgeActivities(widget.fridgeId, type: _currentFilter);
      setState(() {
        _allLogs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nhật ký hoạt động',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allLogs.isEmpty
                    ? const Center(child: Text('Không có hoạt động nào'))
                    : RefreshIndicator(
                        onRefresh: _loadLogs,
                        child: _buildTimeline(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 25),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _currentFilter == filter['value'];
          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                setState(() => _currentFilter = filter['value']!);
                _loadLogs();
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  filter['label']!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                    color: isSelected ? AppColors.primary : Colors.grey[500],
                  ),
                ),
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    height: 3,
                    width: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeline() {
    // Group logs by date
    final Map<String, List<ActivityLogModel>> groupedLogs = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var log in _allLogs) {
      final logDate = DateTime(log.createdAt.year, log.createdAt.month, log.createdAt.day);
      String dateKey;
      if (logDate == today) {
        dateKey = 'HÔM NAY';
      } else if (logDate == yesterday) {
        dateKey = 'HÔM QUA';
      } else {
        dateKey = DateFormat('dd/MM/yyyy').format(logDate);
      }

      if (!groupedLogs.containsKey(dateKey)) {
        groupedLogs[dateKey] = [];
      }
      groupedLogs[dateKey]!.add(log);
    }

    final dateKeys = groupedLogs.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: dateKeys.length,
      itemBuilder: (context, index) {
        final dateKey = dateKeys[index];
        final logs = groupedLogs[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                dateKey,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            ...logs.map((log) => _buildActivityItem(log)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildActivityItem(ActivityLogModel log) {
    IconData icon;
    Color color;
    Color bgColor;

    switch (log.activityType) {
      case 'cook_recipe':
        icon = Icons.restaurant;
        color = const Color(0xFF10B981); // Green
        bgColor = const Color(0xFFD1FAE5);
        break;
      case 'add_item':
        icon = Icons.add_circle;
        color = const Color(0xFF3B82F6); // Blue
        bgColor = const Color(0xFFDBEAFE);
        break;
      case 'use_item':
        icon = Icons.remove_circle;
        color = const Color(0xFFF97316); // Orange
        bgColor = const Color(0xFFFFEDD5);
        break;
      case 'discard_item':
        icon = Icons.delete;
        color = const Color(0xFFEF4444); // Red
        bgColor = const Color(0xFFFEE2E2);
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
        bgColor = Colors.grey[200]!;
    }

    final timeStr = DateFormat('HH:mm').format(log.createdAt);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Expanded(
                child: Container(
                  width: 1,
                  color: Colors.grey[200],
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.displayMessage,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      if (log.activityType == 'cook_recipe')
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Do ${log.userName} thực hiện',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '$timeStr ${log.activityLabel}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
