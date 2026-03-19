import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class HelpFeedbackScreen extends StatefulWidget {
  const HelpFeedbackScreen({super.key});

  @override
  State<HelpFeedbackScreen> createState() => _HelpFeedbackScreenState();
}

class _HelpFeedbackScreenState extends State<HelpFeedbackScreen> {
  final _issueController = TextEditingController();
  final _detailController = TextEditingController();

  @override
  void dispose() {
    _issueController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  void _submitFeedback() {
    if (_issueController.text.trim().isEmpty || _detailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
      );
      return;
    }

    // Mock submission
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cảm ơn bạn đã phản hồi! Chúng tôi sẽ xem xét sớm nhất.'),
        backgroundColor: AppColors.primary,
      ),
    );
    
    _issueController.clear();
    _detailController.clear();
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
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
              hintText: 'Loại vấn đề bạn gặp phải......',
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
              hintText: 'Hãy mô tả vấn đề hoặc ý kiến của bạn....',
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
              onPressed: _submitFeedback,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
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
            subtitle: '1900XXX',
            onTap: () {},
          ),
          _buildDivider(),
          _buildSupportItem(
            icon: Icons.mail_outline,
            iconColor: Colors.blue,
            title: 'Email hỗ trợ',
            subtitle: 'beptroly@gmail.com',
            onTap: () {},
          ),
          _buildDivider(),
          _buildSupportItem(
            icon: Icons.chat_bubble_outline,
            iconColor: Colors.purple,
            title: 'Chat trực tuyến',
            subtitle: 'Phản hồi lập tức',
            onTap: () {},
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
}
