import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../models/shopping_list_item.dart';
import '../../services/local_notification_service.dart';

enum _CookerMode { beginner, experienced }

/// Màn hình Công thức nấu ăn chi tiết - Phiên bản nâng cấp
class CookingDetailScreen extends StatefulWidget {
  final ShoppingListSection section;

  const CookingDetailScreen({super.key, required this.section});

  @override
  State<CookingDetailScreen> createState() => _CookingDetailScreenState();
}

class _CookingDetailScreenState extends State<CookingDetailScreen> {
  static const String _cookerModePrefKey = 'cooking_mode_preference_v1';
  final GlobalKey _step3SectionKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  late List<String> _steps;
  late int _prepStepCount;
  late List<bool> _stepCompleted;
  Timer? _countdownTimer;
  late int _remainingSeconds;
  bool _isTimerRunning = false;
  bool _cookingPhaseStarted = false;
  _CookerMode _cookerMode = _CookerMode.beginner;

  int get _notificationId {
    final recipeKey =
        widget.section.recipeInfo?.recipeId ?? widget.section.title;
    return LocalNotificationService.cookingNotificationId(recipeKey);
  }

  @override
  void initState() {
    super.initState();
    _steps = _resolveSteps();
    _prepStepCount = _detectPrepStepCount(_steps);
    _stepCompleted = List.generate(_steps.length, (index) => false);
    final cookMinutes = widget.section.recipeInfo?.cookTime ?? 0;
    _remainingSeconds = (cookMinutes > 0 ? cookMinutes : 20) * 60;
    _loadSavedCookerMode();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _scrollController.dispose();
    LocalNotificationService.cancelNotification(_notificationId);
    super.dispose();
  }

  double get _progress {
    if (_stepCompleted.isEmpty) return 0;
    final completedCount = _stepCompleted.where((c) => c).length;
    return completedCount / _stepCompleted.length;
  }

  bool get _isPrepDone {
    if (_prepStepCount <= 0) return true;
    for (var i = 0; i < _prepStepCount; i++) {
      if (!_stepCompleted[i]) return false;
    }
    return true;
  }

  int get _currentPrepStepIndex {
    for (var i = 0; i < _prepStepCount; i++) {
      if (!_stepCompleted[i]) return i;
    }
    return -1;
  }

  int get _currentCookingStepIndex {
    for (var i = _prepStepCount; i < _stepCompleted.length; i++) {
      if (!_stepCompleted[i]) return i;
    }
    return -1;
  }

  bool _isStepEnabled(int index) {
    if (_isExperiencedMode) return true;

    if (index < _prepStepCount) {
      final currentPrep = _currentPrepStepIndex;
      if (currentPrep == -1) return _stepCompleted[index];
      return index == currentPrep || _stepCompleted[index];
    }

    if (!_cookingPhaseStarted) return false;

    final currentCooking = _currentCookingStepIndex;
    if (currentCooking == -1) return _stepCompleted[index];
    return index == currentCooking || _stepCompleted[index];
  }

  String _stepLockHint(int index) {
    if (index < _prepStepCount) {
      final currentPrep = _currentPrepStepIndex;
      if (currentPrep == -1) return 'Bạn đã hoàn tất các bước chuẩn bị.';
      return 'Hãy hoàn thành Bước ${currentPrep + 1} trước để mở bước tiếp theo.';
    }

    if (!_cookingPhaseStarted) {
      return 'Hãy bấm "Bước 2: Bắt đầu nấu" sau khi hoàn tất sơ chế.';
    }

    final currentCooking = _currentCookingStepIndex;
    if (currentCooking == -1) return 'Bạn đã hoàn tất các bước nấu.';
    return 'Hãy hoàn thành Bước ${currentCooking + 1} trước để mở bước tiếp theo.';
  }

  bool get _allStepsDone => _stepCompleted.every((c) => c);

  bool get _isExperiencedMode => _cookerMode == _CookerMode.experienced;

  bool get _canFinishDish {
    if (_remainingSeconds > 0) return false;
    if (_isExperiencedMode) return true;
    return _cookingPhaseStarted && _allStepsDone;
  }

  bool get _isReadyForStep2 =>
      !_isExperiencedMode && _isPrepDone && !_cookingPhaseStarted;

  List<String> _resolveSteps() {
    final infoSteps = widget.section.recipeInfo?.steps
        ?.where((e) => e.trim().isNotEmpty)
        .toList();
    if (infoSteps != null && infoSteps.isNotEmpty) {
      return infoSteps;
    }
    return const [
      'Sơ chế nguyên liệu: rửa sạch, cắt và chuẩn bị gia vị.',
      'Chuẩn bị dụng cụ nấu: nồi/chảo, muỗng, bếp ở mức lửa phù hợp.',
      'Bắt đầu nấu: cho nguyên liệu chính vào nồi/chảo theo thứ tự phù hợp.',
      'Nêm nếm, hoàn thiện món ăn và trình bày ra đĩa.',
    ];
  }

  int _detectPrepStepCount(List<String> steps) {
    final cookingKeywords = <String>[
      'bat dau nau',
      'nau',
      'xao',
      'chien',
      'luoc',
      'ham',
      'kho',
      'nuong',
      'ap chao',
      'om',
      'rim',
      'rang',
    ];

    for (var i = 0; i < steps.length; i++) {
      final normalized = _normalize(steps[i]);
      final isCooking = cookingKeywords.any(normalized.contains);
      if (isCooking) {
        return i == 0 ? 1 : i;
      }
    }

    if (steps.length <= 1) return 1;
    return (steps.length / 2).ceil();
  }

  String _normalize(String text) {
    var value = text.toLowerCase();
    const map = {
      'à': 'a',
      'á': 'a',
      'ạ': 'a',
      'ả': 'a',
      'ã': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ậ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ặ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'è': 'e',
      'é': 'e',
      'ẹ': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ệ': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ì': 'i',
      'í': 'i',
      'ị': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ò': 'o',
      'ó': 'o',
      'ọ': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ộ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ợ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ụ': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ự': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỵ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'đ': 'd',
    };
    map.forEach((k, v) => value = value.replaceAll(k, v));
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.section.recipeInfo;
    final hasRecipeInfo = info != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scrollController,
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
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_progress > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
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
                      ? Image.network(info.imageUrl!, fit: BoxFit.cover)
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
                  if (_stepCompleted.isNotEmpty && !_isExperiencedMode) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.divider.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chế độ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Chế độ chi tiết'),
                              selected: _cookerMode == _CookerMode.beginner,
                              onSelected: (_) =>
                                  _setCookerMode(_CookerMode.beginner),
                              showCheckmark: false,
                            ),
                            ChoiceChip(
                              label: const Text('Chế độ nhanh'),
                              selected: _cookerMode == _CookerMode.experienced,
                              onSelected: (_) =>
                                  _setCookerMode(_CookerMode.experienced),
                              showCheckmark: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isExperiencedMode
                              ? 'Nấu quen: bấm giờ nấu và nhận thông báo hoàn tất.'
                              : 'Nấu mới: sơ chế theo từng bước, sau đó mới bắt đầu nấu.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ──── Thông tin nhanh ────
                  if (hasRecipeInfo)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.divider.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat(
                            'Phần ăn',
                            '${info.servings}',
                            Icons.people_outline,
                          ),
                          _buildStat(
                            'Nấu',
                            '${info.cookTime}\'',
                            Icons.timer_outlined,
                          ),
                          _buildStat(
                            'Độ khó',
                            info.difficultyLabel,
                            Icons.workspace_premium_outlined,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.divider.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.timer_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hẹn giờ nấu',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDuration(_remainingSeconds),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            ElevatedButton(
                              onPressed:
                                  (!_cookingPhaseStarted &&
                                          !_isExperiencedMode) ||
                                      _remainingSeconds == 0
                                  ? null
                                  : (_isTimerRunning
                                        ? _pauseTimer
                                        : _startTimer),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(92, 36),
                                elevation: 0,
                              ),
                              child: Text(
                                _isTimerRunning ? 'Tạm dừng' : 'Bắt đầu',
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed:
                                  (_cookingPhaseStarted || _isExperiencedMode)
                                  ? _resetTimer
                                  : null,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(92, 36),
                              ),
                              child: const Text('Đặt lại'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (!_cookingPhaseStarted && !_isExperiencedMode)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        _isPrepDone
                            ? 'Bạn đã hoàn tất sơ chế. Bấm "Bước 2: Bắt đầu nấu" để mở phần nấu và hẹn giờ.'
                            : 'Đây là giai đoạn chuẩn bị/sơ chế, chưa tính là nấu. Hoàn tất tuần tự các bước trước.',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),

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
                      border: Border.all(
                        color: AppColors.divider.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      children: widget.section.items
                          .map((item) => _buildIngredientItem(item))
                          .toList(),
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

                  if (!_isExperiencedMode) ...[
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
                    const Text(
                      'Bước 1: Sơ chế & chuẩn bị',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(
                      _prepStepCount,
                      (index) => _buildStepItem(
                        index,
                        _steps[index],
                        enabled: _isStepEnabled(index),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isPrepDone ? _startCookingPhase : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isReadyForStep2
                              ? const Color(0xFF2E7D32)
                              : AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: _isReadyForStep2
                              ? const BorderSide(
                                  color: Color(0xFFA5D6A7),
                                  width: 1.4,
                                )
                              : null,
                          shadowColor: _isReadyForStep2
                              ? const Color(0x552E7D32)
                              : null,
                          elevation: _isReadyForStep2 ? 3 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _cookingPhaseStarted
                              ? 'Bước 2: Đã bắt đầu nấu'
                              : 'Bước 2: Bắt đầu nấu',
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      key: _step3SectionKey,
                      child: const Text(
                        'Bước 3: Nấu món',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(_steps.length - _prepStepCount, (offset) {
                      final index = _prepStepCount + offset;
                      return _buildStepItem(
                        index,
                        _steps[index],
                        enabled: _isStepEnabled(index),
                      );
                    }),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.divider.withValues(alpha: 0.6),
                        ),
                      ),
                      child: const Text(
                        'Chế độ nhanh: chỉ cần bật hẹn giờ nấu, hệ thống sẽ thông báo khi món hoàn thành.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // ──── Nút hoàn thành ────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!_cookingPhaseStarted && !_isExperiencedMode) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Hãy hoàn tất sơ chế và bấm "Bước 2: Bắt đầu nấu" trước nhé.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        if (_remainingSeconds > 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Thời gian nấu chưa kết thúc, hãy chờ đếm ngược về 00:00.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        if (!_isExperiencedMode && !_allStepsDone) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Hãy hoàn thành tất cả các bước nhé!',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canFinishDish
                            ? AppColors.primary
                            : Colors.grey[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _canFinishDish
                            ? 'Hoàn thành món ăn ✨'
                            : 'Đang thực hiện...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
          style: const TextStyle(fontSize: 11, color: AppColors.textHint),
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

  Widget _buildStepItem(int index, String content, {required bool enabled}) {
    final isCompleted = _stepCompleted[index];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          if (!enabled) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_stepLockHint(index)),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
          if (isCompleted) return;

          final wasPrepDone = _isPrepDone;
          setState(() {
            _stepCompleted[index] = true;
          });

          final isLastPrepStep = index == _prepStepCount - 1;
          if (!wasPrepDone &&
              isLastPrepStep &&
              _isPrepDone &&
              !_isExperiencedMode) {
            _startCookingPhase(autoStartedFromPrep: true);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: !enabled
                ? const Color(0xFFF8FAFC)
                : isCompleted
                ? AppColors.primary.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: !enabled
                  ? const Color(0xFFE2E8F0)
                  : isCompleted
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.divider.withValues(alpha: 0.5),
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
                  color: !enabled
                      ? const Color(0xFFE2E8F0)
                      : isCompleted
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: !enabled
                      ? const Icon(Icons.lock_outline, size: 14)
                      : isCompleted
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
                    color: !enabled
                        ? AppColors.textHint
                        : isCompleted
                        ? AppColors.textHint
                        : AppColors.textPrimary,
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

  void _startTimer() {
    if (!_cookingPhaseStarted && !_isExperiencedMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hãy bấm "Bước 2: Bắt đầu nấu" sau khi hoàn tất sơ chế.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_remainingSeconds <= 0) return;
    setState(() {
      _isTimerRunning = true;
      _cookingPhaseStarted = true;
    });
    LocalNotificationService.scheduleCookingDoneNotification(
      notificationId: _notificationId,
      recipeName: widget.section.title,
      inSeconds: _remainingSeconds,
    );
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _isTimerRunning = false;
          _cookingPhaseStarted = true;
          if (!_isExperiencedMode) {
            for (var i = 0; i < _stepCompleted.length; i++) {
              _stepCompleted[i] = true;
            }
          }
        });
        LocalNotificationService.cancelNotification(_notificationId);
        _notifyCookingDone();
        return;
      }

      setState(() {
        _remainingSeconds -= 1;
      });
    });
  }

  void _pauseTimer() {
    _countdownTimer?.cancel();
    LocalNotificationService.cancelNotification(_notificationId);
    setState(() => _isTimerRunning = false);
  }

  void _resetTimer() {
    _countdownTimer?.cancel();
    LocalNotificationService.cancelNotification(_notificationId);
    final cookMinutes = widget.section.recipeInfo?.cookTime ?? 0;
    setState(() {
      _remainingSeconds = (cookMinutes > 0 ? cookMinutes : 20) * 60;
      _isTimerRunning = false;
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _notifyCookingDone() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Món ăn đã sẵn sàng'),
          content: Text(
            'Đã hết thời gian nấu món "${widget.section.title}". Bạn có thể kiểm tra và thưởng thức.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đã hiểu'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startCookingPhase({bool autoStartedFromPrep = false}) async {
    if (_cookingPhaseStarted) return;
    if (!_isPrepDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn chưa hoàn tất các bước chuẩn bị.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _cookingPhaseStarted = true;
    });

    if (autoStartedFromPrep) {
      await _scrollToCookingSection();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          autoStartedFromPrep
              ? 'Đã hoàn tất sơ chế và tự động chuyển sang phần nấu.'
              : 'Đã bắt đầu giai đoạn nấu. Bạn có thể chạy hẹn giờ.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _scrollToCookingSection() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    if (_scrollController.hasClients) {
      final max = _scrollController.position.maxScrollExtent;
      await _scrollController.animateTo(
        max,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    final targetContext = _step3SectionKey.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.1,
    );
  }

  void _setCookerMode(_CookerMode mode) {
    if (_cookerMode == mode) return;
    setState(() {
      _cookerMode = mode;
      if (_isExperiencedMode) {
        _cookingPhaseStarted = true;
      } else {
        _cookingPhaseStarted = _isPrepDone;
      }
    });
    _saveCookerMode(mode);
  }

  Future<void> _loadSavedCookerMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cookerModePrefKey);
    final mode = raw == 'experienced'
        ? _CookerMode.experienced
        : _CookerMode.beginner;

    if (!mounted) return;
    setState(() {
      _cookerMode = mode;
      _cookingPhaseStarted = _isExperiencedMode || _isPrepDone;
    });
  }

  Future<void> _saveCookerMode(_CookerMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cookerModePrefKey,
      mode == _CookerMode.experienced ? 'experienced' : 'beginner',
    );
  }
}
