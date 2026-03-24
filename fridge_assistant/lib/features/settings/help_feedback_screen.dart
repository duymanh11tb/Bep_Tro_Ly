import 'package:fridge_assistant/core/localization/app_material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/support_service.dart';

class HelpFeedbackScreen extends StatefulWidget {
  const HelpFeedbackScreen({super.key});

  @override
  State<HelpFeedbackScreen> createState() => _HelpFeedbackScreenState();
}

class _HelpFeedbackScreenState extends State<HelpFeedbackScreen> {
  final _issueController = TextEditingController();
  final _detailController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isSubmitting = false;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  @override
  void dispose() {
    _issueController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserEmail() async {
    final user = await _authService.getUser();
    if (!mounted) return;
    setState(() {
      _userEmail = user?['email']?.toString();
    });
  }

  Future<void> _submitFeedback() async {
    if (_issueController.text.trim().isEmpty || _detailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
      );
      return;
    }

    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    final success = await SupportService.sendFeedback(
      issue: _issueController.text,
      detail: _detailController.text,
      userEmail: _userEmail,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã mở ứng dụng email để bạn gửi phản hồi.'),
          backgroundColor: AppColors.primary,
        ),
      );
      _issueController.clear();
      _detailController.clear();
      return;
    }

    await Clipboard.setData(
      const ClipboardData(text: SupportService.supportEmail),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Không mở được email. Đã sao chép địa chỉ hỗ trợ để bạn gửi thủ công.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Trợ giúp & Phản hồi',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('GỬI PHẢN HỒI CHO CHÚNG TÔI'),
            const SizedBox(height: 12),
            _buildFeedbackCard(),
            const SizedBox(height: 32),
            _buildSectionTitle('LIÊN HỆ HỖ TRỢ'),
            const SizedBox(height: 12),
            _buildSupportCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black.withValues(alpha: 0.4),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildFeedbackCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vấn đề bạn gặp phải',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _issueController,
            decoration: InputDecoration(
              hintText: context.tr('Loại vấn đề bạn gặp phải......'),
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
          if (_userEmail != null && _userEmail!.isNotEmpty) ...[
            Text(
              'Phản hồi sẽ được gửi kèm email tài khoản: $_userEmail',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Chi tiết phản hồi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _detailController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: context.tr('Hãy mô tả vấn đề hoặc ý kiến của bạn....'),
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitFeedback,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Gửi phản hồi',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSupportItem(
            icon: Icons.phone_in_talk_outlined,
            iconColor: Colors.red,
            title: 'Hotline',
            subtitle: SupportService.supportPhone,
            onTap: _openHotline,
          ),
          _buildDivider(),
          _buildSupportItem(
            icon: Icons.mail_outline,
            iconColor: Colors.blue,
            title: 'Email hỗ trợ',
            subtitle: SupportService.supportEmail,
            onTap: _openSupportEmail,
          ),
          _buildDivider(),
          _buildSupportItem(
            icon: Icons.chat_bubble_outline,
            iconColor: Colors.purple,
            title: 'Nhắn Zalo',
            subtitle: 'Mở Zalo hỗ trợ: ${SupportService.supportPhone}',
            onTap: _openSupportChat,
          ),
        ],
      ),
    );
  }

  Widget _buildSupportItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey[100],
      indent: 20,
      endIndent: 20,
    );
  }

  Future<void> _openHotline() async {
    final success = await SupportService.callSupport();
    await _handleLaunchResult(
      success: success,
      fallbackText: SupportService.supportPhone,
      successMessage: 'Đang mở trình gọi điện hỗ trợ.',
      failureMessage: 'Không mở được trình gọi điện. Đã sao chép số hotline.',
    );
  }

  Future<void> _openSupportEmail() async {
    final success = await SupportService.emailSupport(
      subject: '[Hỗ trợ] Bếp Trợ Lý',
      body: 'Xin chào, tôi cần được hỗ trợ thêm về ứng dụng.',
    );
    await _handleLaunchResult(
      success: success,
      fallbackText: SupportService.supportEmail,
      successMessage: 'Đã mở ứng dụng email hỗ trợ.',
      failureMessage: 'Không mở được email. Đã sao chép địa chỉ hỗ trợ.',
    );
  }

  Future<void> _openSupportChat() async {
    final success = await SupportService.openChatSupport(
      message: 'Xin chào, tôi cần được hỗ trợ nhanh về ứng dụng Bếp Trợ Lý.',
    );
    await _handleLaunchResult(
      success: success,
      fallbackText: SupportService.supportZaloUrl,
      successMessage: 'Đã mở Zalo hỗ trợ.',
      failureMessage: 'Không mở được Zalo. Đã sao chép đường dẫn hỗ trợ.',
    );
  }

  Future<void> _handleLaunchResult({
    required bool success,
    required String fallbackText,
    required String successMessage,
    required String failureMessage,
  }) async {
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: fallbackText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failureMessage)),
    );
  }
}
